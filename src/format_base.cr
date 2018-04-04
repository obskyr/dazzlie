require "stumpy_png"
require "./layout"

module Dazzlie
    class TileFormat < LayoutLevel
        @direction = Direction::Horizontal
        @num = 1

        # These four need to be overridden in formats.
        @@description = "A format without a description."
        @@bytes_per_tile = 0
        @@px_width  = 0
        @@px_height = 0

        def initialize
            @px_width  = @@px_width
            @px_height = @@px_height
        end

        def encode(canvas : StumpyPNG::Canvas, to : IO, num_tiles : Int32, x : Int32, y : Int32)
            return self.encode canvas, to, x, y
        end

        def encode(canvas : StumpyPNG::Canvas, to : IO, x : Int32, y : Int32)
            raise NotImplementedError.new
        end

        def decode(from : IO, canvas : StumpyPNG::Canvas, num_tiles : Int32, x : Int32, y : Int32)
            return self.decode from, canvas, x, y
        end

        def decode(from : IO, canvas : StumpyPNG::Canvas, x : Int32, y : Int32)
            raise NotImplementedError.new
        end

        def self.description
            return @@description
        end

        def self.bytes_per_tile
            return @@bytes_per_tile
        end

        def bytes_per_tile
            return @@bytes_per_tile
        end

        def self.px_width
            return @@px_width
        end

        def self.px_height
            return @@px_height
        end
    end
end
