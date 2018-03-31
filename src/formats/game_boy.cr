require "../format_base"

private PALETTE_2BPP = {
    {0xFF, 0xFF, 0xFF},
    {0xA9, 0xA9, 0xA9},
    {0x55, 0x55, 0x55},
    {0x00, 0x00, 0x00}
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

private PALETTE_1BPP = {
    {0xFF, 0xFF, 0xFF},
    {0x00, 0x00, 0x00}
}.map { |c| StumpyPNG::RGBA.from_rgb_n(c[0], c[1], c[2], 8) }

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
                canvas[cur_x, cur_y] = PALETTE_2BPP[i]
            end
        end

        return 1
    end
end

private class GameBoyTileFormat < Dazzlie::TileFormat
    @@px_width  = 8
    @@px_height = 8
end

private class TileFormat_Gb2Bpp < GameBoyTileFormat
    @@description = "Game Boy (Color) tiles at 2 bits per pixel."
    @@bytes_per_tile = 16

    define_gb_decode 8, 2
end

private class TileFormat_Gb1Bpp < GameBoyTileFormat
    @@description = "Game Boy (Color) tiles at 1 bit per pixel."
    @@bytes_per_tile = 8

    define_gb_decode 8, 1
end

module Dazzlie
    module Formats
        Gb2Bpp = TileFormat_Gb2Bpp
        Gb1Bpp = TileFormat_Gb1Bpp
    end
end
