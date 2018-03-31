module Dazzlie
    private enum Direction
        Horizontal
        Vertical
    end

    private class LayoutLevel
        getter direction : Direction
        getter num : Int32?
        getter px_width  : Int32
        getter px_height : Int32

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

        def decode(from : IO, canvas : StumpyPNG::Canvas, num_tiles : Int32, x : Int32, y : Int32)
            raise NotImplementedError.new
        end
    end

    private class ChunkLevel < LayoutLevel
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

        def decode(from : IO, canvas : StumpyPNG::Canvas, num_tiles : Int32, x : Int32, y : Int32)
            total_decoded = 0
            
            # It feels like there should be a better way to make an infinite
            # iterator than `1.times.cycle`, but `loop` can't be assigned...
            times = (num = @num) ? num.times : 1.times.cycle
            times.each do
                tiles_left = num_tiles - total_decoded
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
end
