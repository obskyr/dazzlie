require "../format_base"
require "../errors"

private NES_INDEX_TO_COLOR_2BPP = {
    {0x00, 0x00, 0x00},
    {0x55, 0x55, 0x55},
    {0xA9, 0xA9, 0xA9},
    {0xFF, 0xFF, 0xFF},
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

private NES_INDEX_TO_COLOR_1BPP = {
    {0x00, 0x00, 0x00},
    {0xFF, 0xFF, 0xFF},
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

private NES_COLOR_TO_INDEX_2BPP = {} of StumpyPNG::RGBA => Int32
NES_INDEX_TO_COLOR_2BPP.each_with_index { |c, i| NES_COLOR_TO_INDEX_2BPP[c] = i}

private NES_COLOR_TO_INDEX_1BPP = {} of StumpyPNG::RGBA => Int32
NES_INDEX_TO_COLOR_1BPP.each_with_index { |c, i| NES_COLOR_TO_INDEX_1BPP[c] = i}

private macro define_nes_encode(bytes_per_row)
    def encode(canvas : StumpyPNG::Canvas, to : IO, x : Int32, y : Int32)
        return 0 if !canvas.includes_pixel? x, y
        tile = Bytes.new @@bytes_per_tile
        
        (y...y + px_height).each.zip((0...px_height).each).each do |cur_y, tile_y|
            {% for bpp in (0..bytes_per_row-1) %}
                tile[tile_y + {{bpp}}*px_height] = 0_u8
            {% end %}
            (x...x + px_width).each.zip((0...px_width).reverse_each).each do |cur_x, tile_x|
                cur_color = canvas.safe_get cur_x, cur_y

                begin
                    if cur_color
                        i = cur_color.a == 0 ? 0 : NES_COLOR_TO_INDEX_{{bytes_per_row.id}}BPP[cur_color]
                    else
                        i = 0
                    end
                rescue KeyError
                    raise Dazzlie::GraphicsConversionError.new(
                        "Encountered a pixel with an invalid color for NES graphics."
                    )
                end
                
                {% for bpp in (0..bytes_per_row-1) %}
                    tile[tile_y + {{bpp}}*px_height] |= ((i >> {{bpp}}) & 1) << tile_x
                {% end %}
                
            end
        end
        (0..bytes_per_tile-1).each do |byte|
            to.write_byte tile[byte]
        end
        
        return 1
    end
end

private macro define_nes_decode(bytes_per_row)
    def decode(from : IO, canvas : StumpyPNG::Canvas, x : Int32, y : Int32)
        tile = Bytes.new @@bytes_per_tile
        bytes_read = from.read tile
        return 0 if bytes_read == 0
            
        (y...y + px_height).each.zip((0...px_height).each).each do |cur_y, tile_y|
            (x...x + px_width).each.zip((0...px_width).reverse_each).each do |cur_x, low_shift_distance|
                i = ((tile[tile_y] >> low_shift_distance) & 0b1) {% for i in (1..bytes_per_row-1) %} | \
                    ((tile[tile_y + {{i.id}}*px_height] >> low_shift_distance) & 0b1) << 1 {% end %}
                canvas[cur_x, cur_y] = NES_INDEX_TO_COLOR_{{bytes_per_row.id}}BPP[i]
            end
        end

        return 1
    end
end

private abstract class NESTileFormat < Dazzlie::TileFormat
    @@px_width  = 8
    @@px_height = 8
end

private class TileFormat_NES2Bpp < NESTileFormat
    @@description = "NES tiles at 2 bits per pixel."
    @@bytes_per_tile = 16

    define_nes_encode 2
    define_nes_decode 2
end

private class TileFormat_NES1Bpp < NESTileFormat
    @@description = "NES tiles at 1 bit per pixel."
    @@bytes_per_tile = 8

    define_nes_encode 1
    define_nes_decode 1
end

module Dazzlie
    private module Formats
        NES2Bpp = TileFormat_NES2Bpp
        NES1Bpp = TileFormat_NES1Bpp
        NESRow2Bpp = TileFormat_NESRow2Bpp
        NESRow1Bpp = TileFormat_NESRow1Bpp
    end
end
