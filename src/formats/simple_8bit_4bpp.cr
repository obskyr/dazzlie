require "../format_base"
require "../errors"

private SIMPLE_8BIT_INDEX_TO_COLOR_4BPP = {
    {0xFF, 0xFF, 0xFF},    
    {0xEE, 0xEE, 0xEE},    
    {0xDD, 0xDD, 0xDD},    
    {0xCC, 0xCC, 0xCC},    
    {0xBB, 0xBB, 0xBB},    
    {0xAA, 0xAA, 0xAA},    
    {0x99, 0x99, 0x99},    
    {0x88, 0x88, 0x88},    
    {0x77, 0x77, 0x77},    
    {0x66, 0x66, 0x66},    
    {0x55, 0x55, 0x55},    
    {0x44, 0x44, 0x44},    
    {0x33, 0x33, 0x33},    
    {0x22, 0x22, 0x22},    
    {0x11, 0x11, 0x11},    
    {0x00, 0x00, 0x00},
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

private SIMPLE_8BIT_COLOR_TO_INDEX_4BPP = {} of StumpyPNG::RGBA => Int32
SIMPLE_8BIT_INDEX_TO_COLOR_4BPP.each_with_index { |c, i| SIMPLE_8BIT_COLOR_TO_INDEX_4BPP[c] = i}

private class TileFormat_Simple8Bit4Bpp < Dazzlie::TileFormat
    @@description = "Byte-by-byte graphics at 4 bits per pixel; first pixel low."
    @@px_width  = 2
    @@px_height = 1
    @@bytes_per_tile = 1

    def encode(canvas : StumpyPNG::Canvas, to : IO, x : Int32, y : Int32)
        return 0 if !canvas.includes_pixel? x, y

        byte = 0_u8

        (x...x + 2).each.zip((0..4).step(4).each).each do |cur_x, low_shift_distance|
            cur_color = canvas.safe_get cur_x, y

            begin
                if cur_color
                    i = cur_color.a == 0 ? 0 : SIMPLE_8BIT_COLOR_TO_INDEX_4BPP[cur_color]
                else
                    i = 0
                end
            rescue KeyError
                raise Dazzlie::GraphicsConversionError.new(
                    "Encountered a pixel with an invalid color for Game Boy graphics."
                )
            end

            byte |= i << low_shift_distance
        end

        to.write_byte byte

        return 1
    end
    
    def decode(from : IO, canvas : StumpyPNG::Canvas, x : Int32, y : Int32)
        tile = Bytes.new @@bytes_per_tile
        bytes_read = from.read tile
        return 0 if bytes_read == 0
        tile_io = IO::Memory.new tile[0, bytes_read]

        byte = tile_io.read_byte.not_nil!

        (x...x + 2).each.zip((0..4).step(4).each).each do |cur_x, low_shift_distance|
            i = ((byte >> low_shift_distance) & 0b1111)
            canvas[cur_x, y] = SIMPLE_8BIT_INDEX_TO_COLOR_4BPP[i]
        end

        return 1
    end
end

module Dazzlie
    private module Formats
        Simple8Bit4Bpp = TileFormat_Simple8Bit4Bpp
    end
end
