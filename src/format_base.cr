require "./layout"

module Dazzlie
    class TileFormat < LayoutLevel
        @direction = Direction::Horizontal
        @num = 1

        # These two need to be overridden in formats.
        @px_width  = 0
        @px_height = 0

        @@description = "A format without a description."

        def initialize
        end

        def self.description
            return @@description
        end
    end
end
