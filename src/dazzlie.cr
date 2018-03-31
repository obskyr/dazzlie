# Decode tile graphics to PNG.

require "stumpy_png"
require "./format_base"
require "./formats"
require "./layout"

private def round_up(num, multiple)
    return num if multiple == 0
    remainder = num % multiple
    return num if remainder == 0
    return num + multiple - remainder
end

module Dazzlie
    # Shim until the Crystal version after 0.24.2 comes out.
    class NotImplementedError < Exception
    end

    class GraphicsConversionError < ArgumentError
    end

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

        def decode(from : IO, to : IO, num_tiles : Int32?)
            raise GraphicsConversionError.new "Number of tiles must be greater than 0." if num_tiles && num_tiles <= 0

            # The final dimensions of the image need to be determined differently
            # depending on whether the layout has an infinite dimension or not:
            # if not, it's just the layout's width and height, but if it does,
            # the dimensions are based on how much data there is.
            if @top_level.num
                if num_tiles && (@top_level.px_width / 8) * (@top_level.px_height / 8) < num_tiles
                    raise GraphicsConversionError.new "Layout dimensions too small to fit #{num_tiles} tiles."
                end
                width  = @top_level.px_width
                height = @top_level.px_height
            else
                original_from = from
                if num_tiles
                    num_pixels = 8 * 8 * num_tiles
                    num_bytes = @tile_format.bytes_per_tile * num_tiles
                    bytes = Bytes.new num_bytes
                    bytes_read = original_from.read bytes
                    
                    # If the bytes read stop in the middle of a tile, the tile
                    # decoder will still be able to read that tile. Therefore,
                    # missing a few bytes of the last tile is acceptable.
                    readable_bytes = round_up bytes_read, @tile_format.bytes_per_tile
                    if readable_bytes < num_bytes
                        raise GraphicsConversionError.new "There are less than #{num_tiles} tiles in the input data."
                    end

                    from = IO::Memory.new bytes[0, bytes_read]
                else
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

    def decode(from, to, layout, format, num_tiles)
        transcoder = Transcoder.new format, layout
        transcoder.decode(from, to, num_tiles)
    end
end
