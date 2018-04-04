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

        def encode(canvas : StumpyPNG::Canvas, to : IO, num_tiles : Int32, x : Int32, y : Int32)
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

        private def each_chunk(canvas, num_tiles, x, y, &block : Int32, Int32, Int32 -> {Int32, Int32, Int32}) : Int32
            tiles_so_far = 0

            # It feels like there should be a better way to make an infinite
            # iterator than `1.times.cycle`, but `loop` can't be assigned...
            times = (num = @num) ? num.times : 1.times.cycle
            times.each do
                tiles_left = num_tiles - tiles_so_far
                cur_tiles, x, y = yield tiles_left, x, y
                break if cur_tiles == 0
                tiles_so_far += cur_tiles
                break if tiles_so_far == num_tiles
                # No break condition for going off the canvas needs to exist
                # as long as num_tiles is set correctly by the caller and
                # x, y only goes off the canvas at the end of the data.
                # As long as those are true, num_tiles will always have been
                # reached by the time x, y reaches the bottom right corner.
            end

            return tiles_so_far
        end

        def encode(canvas : StumpyPNG::Canvas, to : IO, num_tiles : Int32, x : Int32, y : Int32)
            return each_chunk(canvas, num_tiles, x, y) do |tiles_left, x, y|
                cur_encoded = @child.encode(canvas, to, tiles_left, x, y)

                # Infinite layouts should wrap for convenience.
                if is_horizontal
                    x += @child.px_width
                    if !num && x == canvas.width
                        x = 0
                        y += @child.px_height
                    end
                else
                    y += @child.px_height
                    if !num && y == canvas.height
                        y = 0
                        x += @child.px_width
                    end
                end

                {cur_encoded, x, y}
            end
        end

        def decode(from : IO, canvas : StumpyPNG::Canvas, num_tiles : Int32, x : Int32, y : Int32)
            return each_chunk(canvas, num_tiles, x, y) do |tiles_left, x, y|
                cur_decoded = @child.decode(from, canvas, tiles_left, x, y)

                x += @child.px_width  if is_horizontal
                y += @child.px_height if is_vertical

                {cur_decoded, x, y}
            end
        end
    end
end
