require "../format_base"
require "../errors"

private GB_INDEX_TO_COLOR_2BPP = {
    {0xFF, 0xFF, 0xFF},
    {0xA9, 0xA9, 0xA9},
    {0x55, 0x55, 0x55},
    {0x00, 0x00, 0x00}
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

private GB_INDEX_TO_COLOR_1BPP = {
    {0xFF, 0xFF, 0xFF},
    {0x00, 0x00, 0x00}
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

private GB_COLOR_TO_INDEX_2BPP = {} of StumpyPNG::RGBA => Int32
GB_INDEX_TO_COLOR_2BPP.each_with_index { |c, i| GB_COLOR_TO_INDEX_2BPP[c] = i}

private GB_COLOR_TO_INDEX_1BPP = {} of StumpyPNG::RGBA => Int32
GB_INDEX_TO_COLOR_1BPP.each_with_index { |c, i| GB_COLOR_TO_INDEX_1BPP[c] = i}

private macro define_gb_encode(rows, bytes_per_row)
    def encode(canvas : StumpyPNG::Canvas, to : IO, x : Int32, y : Int32)
        return 0 if !canvas.includes_pixel? x, y

        (y...y + {{rows}}).each do |cur_y|
            {% for i in 1..bytes_per_row %}
                byte_{{i.id}} = 0_u8
            {% end %}

            (x...x + 8).each.zip((0...8).reverse_each).each do |cur_x, low_shift_distance|
                cur_color = canvas.safe_get cur_x, cur_y

                begin
                    if cur_color
                        i = cur_color.a == 0 ? 0 : GB_COLOR_TO_INDEX_{{bytes_per_row.id}}BPP[cur_color]
                    else
                        i = 0
                    end
                rescue KeyError
                    raise Dazzlie::GraphicsConversionError.new(
                        "Encountered a pixel with an invalid color for Game Boy graphics."
                    )
                end

                byte_1 |= (i & 0b1) << low_shift_distance
                {% for i in (2..bytes_per_row) %}
                    # Yay, Crystal handles negative bit shifts properly!
                    byte_{{i.id}} |= (i & {{1 << (i - 1)}}) << (low_shift_distance - {{i - 1}})
                {% end %}
            end

            {% for i in 1..bytes_per_row %}
                to.write_byte byte_{{i.id}}
            {% end %}
        end

        return 1
    end
end

private macro define_gb_decode(rows, bytes_per_row)
    def decode(from : IO, canvas : StumpyPNG::Canvas, x : Int32, y : Int32)
        tile = Bytes.new @@bytes_per_tile
        bytes_read = from.read tile
        return 0 if bytes_read == 0
        tile_io = IO::Memory.new tile[0, bytes_read]

        (y...y + {{rows}}).each do |cur_y|
            # If data stops in the middle of a tile, the rest of the tile
            # should still be filled with something. 0x00, for example.
            {% for i in (1..bytes_per_row) %}
                byte_{{i.id}} = tile_io.read_byte || 0x00
            {% end %}

            (x...x + 8).each.zip((0...8).reverse_each).each do |cur_x, low_shift_distance|
                i = ((byte_1 >> low_shift_distance) & 0b1) {% for i in (2..bytes_per_row) %} | \
                    (((byte_{{i.id}} >> low_shift_distance) << {{i - 1}}) & {{1 << (i - 1)}}) {% end %}
                canvas[cur_x, cur_y] = GB_INDEX_TO_COLOR_{{bytes_per_row.id}}BPP[i]
            end
        end

        return 1
    end
end

private abstract class GameBoyTileFormat < Dazzlie::TileFormat
    @@px_width  = 8
    @@px_height = 8
end

private class TileFormat_Gb2Bpp < GameBoyTileFormat
    @@description = "Game Boy (Color) tiles at 2 bits per pixel."
    @@bytes_per_tile = 16

    define_gb_encode 8, 2
    define_gb_decode 8, 2
end

private class TileFormat_Gb1Bpp < GameBoyTileFormat
    @@description = "Game Boy (Color) tiles at 1 bit per pixel."
    @@bytes_per_tile = 8

    define_gb_encode 8, 1
    define_gb_decode 8, 1
end

private abstract class GameBoyRowFormat < Dazzlie::TileFormat
    @@px_width  = 8
    @@px_height = 1
end

private class TileFormat_GbRow2Bpp < GameBoyRowFormat
    @@description = "Game Boy (Color) sub-tile pixel rows at 2 bits per pixel."
    @@bytes_per_tile = 2

    define_gb_encode 1, 2
    define_gb_decode 1, 2
end

private class TileFormat_GbRow1Bpp < GameBoyRowFormat
    @@description = "Game Boy (Color) sub-tile pixel rows at 1 bit per pixel."
    @@bytes_per_tile = 1

    define_gb_encode 1, 1
    define_gb_decode 1, 1
end

module Dazzlie
    private module Formats
        Gb2Bpp = TileFormat_Gb2Bpp
        Gb1Bpp = TileFormat_Gb1Bpp
        GbRow2Bpp = TileFormat_GbRow2Bpp
        GbRow1Bpp = TileFormat_GbRow1Bpp
    end
end
