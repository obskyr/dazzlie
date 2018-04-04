# Dazzlie: convert between various tile graphics formats and PNG!

require "stumpy_png"
require "./errors"
require "./format_base"
require "./formats"
require "./layout"

private def round_up(num, multiple)
    return num if multiple == 0
    remainder = num % multiple
    return num if remainder == 0
    return num + multiple - remainder
end

private def read_tiles(from, tile_format, num_tiles)
    num_bytes = tile_format.bytes_per_tile * num_tiles
    bytes = Bytes.new num_bytes
    bytes_read = from.read bytes
    
    # If the bytes read stop in the middle of a tile, the tile
    # decoder will still be able to read that tile. Therefore,
    # missing a few bytes of the last tile is acceptable.
    readable_bytes = round_up bytes_read, tile_format.bytes_per_tile
    if readable_bytes == 0
        raise GraphicsConversionError.new "No data to decode."
    elsif readable_bytes < num_bytes
        raise GraphicsConversionError.new(
            "Insufficient input data. At least #{num_tiles} tiles needed; " \
            "found only #{readable_bytes / tile_format.bytes_per_tile}."
        )
    end

    return bytes[0, bytes_read]
end

module Dazzlie
    class Transcoder
        @tile_format : TileFormat
        @top_level : ChunkLevel

        def initialize(format : String, layout : String)
            if !FORMATS.has_key? format
                raise GraphicsConversionError.new %(Format "#{format}" does not exist.)
            end
            if !/^\s*((?:H|V)[0-9]*\s*)+$/i.match layout
                raise GraphicsConversionError.new "Invalid layout string format."
            end

            @tile_format = FORMATS[format].new

            matches = layout.scan /(H|V)([0-9]*)/i
            prev_level = nil
            matches.each do |m|
                direction = m[1].upcase == "H" ? Direction::Horizontal : Direction::Vertical
                num = m[2].to_i?

                if num == 0
                    raise GraphicsConversionError.new "Invalid layout. 0 is not a valid length."
                end

                prev_level = ChunkLevel.new direction, num, prev_level || @tile_format
            end

            @top_level = prev_level.not_nil!
        end

        def encode(from : IO, to : IO, num_tiles : Int32?)
            if num_tiles && num_tiles <= 0
                raise GraphicsConversionError.new "Number of tiles must be greater than 0."
            end

            begin
                canvas = StumpyPNG.read from
            rescue
                raise GraphicsConversionError.new "Failed to parse PNG."
            end

            max_num_tiles = (canvas.width * canvas.height) / (@tile_format.px_width * @tile_format.px_height)
            if !num_tiles
                num_tiles = max_num_tiles
            elsif num_tiles > max_num_tiles
                raise GraphicsConversionError.new "Input image contains fewer than #{num_tiles} tiles."
            end

            if @top_level.num
                if !(canvas.width  == @top_level.px_width &&
                     canvas.height == @top_level.px_height)
                    raise GraphicsConversionError.new(
                        "The size of the provided layout " \
                        "(#{@top_level.px_width}x#{@top_level.px_height}) doesn't match" \
                        "that of the input PNG (#{canvas.width}x#{canvas.height})."
                    )
                end
            else
                if !(canvas.width  % @top_level.px_width  == 0 &&
                     canvas.height % @top_level.px_height == 0)
                    raise GraphicsConversionError.new(
                        "When repeated, the provided layout " \
                        "(#{@top_level.px_width}x#{@top_level.px_height} pixels) " \
                        "doesn't fit evenly into the input PNG " \
                        "(#{canvas.width}x#{canvas.height} pixels)."
                    )
                end
            end

            @top_level.encode canvas, to, num_tiles, 0, 0
        end

        def decode(from : IO, to : IO, num_tiles : Int32?)
            if num_tiles && num_tiles <= 0
                raise GraphicsConversionError.new "Number of tiles must be greater than 0."
            end

            # The final dimensions of the image need to be determined differently
            # depending on whether the layout has an infinite dimension or not:
            # if not, it's just the layout's width and height, but if it does,
            # the dimensions are based on how much data there is.
            if @top_level.num
                width  = @top_level.px_width
                height = @top_level.px_height
                max_num_tiles = (width * height) / (@tile_format.px_width * @tile_format.px_height)
                if num_tiles && num_tiles > max_num_tiles
                    raise GraphicsConversionError.new "Layout dimensions too small to fit #{num_tiles} tiles."
                end
                num_tiles = max_num_tiles if !num_tiles

                from = IO::Memory.new read_tiles(from, @tile_format, num_tiles)
            else
                if num_tiles
                    num_pixels = @tile_format.px_width * @tile_format.px_height * num_tiles
                    from = IO::Memory.new read_tiles(from, @tile_format, num_tiles)
                else
                    original_from = from
                    from = IO::Memory.new
                    IO.copy original_from, from
                    bytes_read = from.tell
                    num_tiles = (bytes_read + @tile_format.bytes_per_tile - 1) / @tile_format.bytes_per_tile
                    num_pixels = num_tiles * @tile_format.px_width * @tile_format.px_height

                    if num_pixels == 0
                        raise GraphicsConversionError.new "No data to decode."
                    end

                    from.seek 0
                end

                pixels_in_top_chunk = @top_level.px_width * @top_level.px_height
                num_pixels = round_up num_pixels, pixels_in_top_chunk

                width  = (@top_level.is_horizontal) ? num_pixels / @top_level.px_height : @top_level.px_width
                height = (@top_level.is_vertical)   ? num_pixels / @top_level.px_width  : @top_level.px_height
            end

            canvas = StumpyPNG::Canvas.new width, height

            @top_level.decode from, canvas, num_tiles, 0, 0

            StumpyPNG.write canvas, to
        end
    end

    def encode(from : IO, to : IO, layout : String, format : String, num_tiles : Int32?)
        transcoder = Transcoder.new format, layout
        transcoder.encode from, to, num_tiles
    end

    def decode(from : IO, to : IO, layout : String, format : String, num_tiles : Int32?)
        transcoder = Transcoder.new format, layout
        transcoder.decode from, to, num_tiles
    end
end
