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
