require "./formats/*"

module Dazzlie
    FORMATS = {
        "gb_2bpp"          => Formats::Gb2Bpp,
        "gb_1bpp"          => Formats::Gb1Bpp,
        "gb_rows_2bpp"     => Formats::GbRow2Bpp,
        "gb_rows_1bpp"     => Formats::GbRow1Bpp,
        "nes_2bpp"         => Formats::Nes2Bpp,
        "nes_1bpp"         => Formats::Nes1Bpp,
        "simple_8bit_4bpp" => Formats::Simple8Bit4Bpp
    }
end
