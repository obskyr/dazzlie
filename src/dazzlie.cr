# Decode tile graphics to PNG.

require "stumpy_png"

# These default palettes need to be put together with the formats.
PALETTE_2BPP = {
    {0xFF, 0xFF, 0xFF},
    {0xA9, 0xA9, 0xA9},
    {0x55, 0x55, 0x55},
    {0x00, 0x00, 0x00}
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

PALETTE_1BPP = {
    {0xFF, 0xFF, 0xFF},
    {0x00, 0x00, 0x00}
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

enum Direction
    Horizontal
    Vertical
end

def round_up(num, multiple)
    return num if multiple == 0
    remainder = num % multiple
    return num if remainder == 0
    return num + multiple - remainder
end

# Shim until the Crystal version after 0.24.2 comes out.
class NotImplementedError < Exception
end

class GraphicsConversionError < ArgumentError
end

class Transcoder
    @top_level : ChunkLevel

    def initialize(layout : String, @bit_depth : Int32)
        raise GraphicsConversionError.new "Invalid bit depth." if !(1 <= bit_depth <= 2)
        if !/^\s*((?:H|V)[0-9]*\s*)+$/i.match layout
            raise GraphicsConversionError.new "Invalid layout string format."
        end
        tile_level = @bit_depth == 2 ? TileLevel2Bpp.new : TileLevel1Bpp.new

        matches = layout.scan /(H|V)([0-9]*)/i
        prev_level = nil
        matches.each do |m|
            direction = m[1].upcase == "H" ? Direction::Horizontal : Direction::Vertical
            num = m[2].to_i?

            if num == 0
                raise GraphicsConversionError.new "Invalid layout. 0 is not a valid length."
            end

            prev_level = ChunkLevel.new direction, num, prev_level || tile_level
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
                num_bytes = @bit_depth * (num_pixels / 8)
                bytes = Bytes.new num_bytes
                bytes_read = original_from.read bytes
                
                # If the bytes read stop in the middle of a tile, the tile
                # decoder will still be able to read that tile. Therefore,
                # missing a few bytes of the last tile is acceptable.
                readable_bytes = round_up bytes_read, @bit_depth * 8
                if readable_bytes < num_bytes
                    raise GraphicsConversionError.new "There are less than #{num_tiles} tiles in the input data."
                end

                from = IO::Memory.new bytes[0, bytes_read]
            else
                from = IO::Memory.new
                IO.copy original_from, from
                bytes_read = from.tell
                num_pixels = ((bytes_read + @bit_depth - 1) / @bit_depth) * 8

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

class LayoutLevel
    property direction : Direction
    property num : Int32?
    property px_width  : Int32
    property px_height : Int32

    def is_horizontal
        return @direction == Direction::Horizontal
    end

    def is_vertical
        return @direction == Direction::Vertical
    end

    def initialize
        # These don't actually do anything except make the compiler happy.
        # Gotta initialize those non-nilable values, you know.
        @direction = Direction::Horizontal
        @px_width  = 0
        @px_height = 0
        raise NotImplementedError.new
    end

    def decode(from : IO, canvas : StumpyPNG::Canvas, num_tiles : Int32?, x : Int32, y : Int32)
        raise NotImplementedError.new
    end
end

class ChunkLevel < LayoutLevel
    def initialize(@direction : Direction, num : Int32?, @child : LayoutLevel)
        @num = num

        if !@child.num
            raise GraphicsConversionError.new %("Invalid layout. Infinite layout levels ("H" or "V") must be at the end.)
        end

        horizontal_children = num ? (is_horizontal ? num : 1) : 1
        vertical_children   = num ? (is_vertical   ? num : 1) : 1
        @px_width  = @child.px_width  * horizontal_children
        @px_height = @child.px_height * vertical_children
    end

    def decode(from : IO, canvas : StumpyPNG::Canvas, num_tiles : Int32?, x : Int32, y : Int32)
        total_decoded = 0
        
        # It feels like there should be a better way to make an infinite
        # iterator than `1.times.cycle`, but `loop` can't be assigned...
        times = (num = @num) ? num.times : 1.times.cycle
        times.each do
            tiles_left = num_tiles ? num_tiles - total_decoded : nil
            cur_decoded = @child.decode(from, canvas, tiles_left, x, y)
            break if cur_decoded == 0

            x += @child.px_width  if is_horizontal
            y += @child.px_height if is_vertical

            total_decoded += cur_decoded
            break if total_decoded == num_tiles
        end

        return total_decoded
    end
end

class TileLevel < LayoutLevel
    @direction = Direction::Horizontal
    @num = 1
    @px_width  = 8
    @px_height = 8

    def initialize
    end
end

class TileLevel2Bpp < TileLevel
    def decode(from : IO, canvas : StumpyPNG::Canvas, num_tiles : Int32?, x : Int32, y : Int32)
        tile = Bytes.new 2 * 8 # 2 bytes per row * 8 rows
        bytes_read = from.read tile
        return 0 if bytes_read == 0
        tile_io = IO::Memory.new tile[0, bytes_read]

        (y...y + 8).each do |cur_y|
            # If data stops in the middle of a tile, the rest of the tile
            # should still be filled with something. 0x00, for example.
            byte_1 = tile_io.read_byte || 0x00
            byte_2 = tile_io.read_byte || 0x00

            (x...x + 8).each.zip((0...8).reverse_each).each do |cur_x, low_shift_distance|
                i = ((byte_1 >> low_shift_distance) & 0b1) | (((byte_2 >> low_shift_distance) << 1) & 0b10)
                canvas[cur_x, cur_y] = PALETTE_2BPP[i]
            end
        end

        return 1
    end
end

class TileLevel1Bpp < TileLevel
    def decode(from : IO, canvas : StumpyPNG::Canvas, num_tiles : Int32?, x : Int32, y : Int32)
        tile = Bytes.new 1 * 8 # 1 byte per row * 8 rows
        bytes_read = from.read tile
        return 0 if bytes_read == 0
        tile_io = IO::Memory.new tile[0, bytes_read]
        
        (y...y + 8).each do |cur_y|
            # Same as with 2BPP - nonexistent data should be filled out.
            byte = tile_io.read_byte || 0x00

            (x...x + 8).each.zip((0...8).reverse_each).each do |cur_x, shift_distance|
                i = (byte >> shift_distance) & 0b1
                canvas[cur_x, cur_y] = PALETTE_1BPP[i]
            end
        end

        return 1
    end
end

def decode(from, to, layout, bit_depth, num_tiles)
    transcoder = Transcoder.new layout, bit_depth
    transcoder.decode(from, to, num_tiles)
end
