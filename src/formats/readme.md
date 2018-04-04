# Adding formats

To add a format to Dazzlie, you'll need to do two things:

1. Write a tile format class that contains `#encode` and `#decode` methods and info about the format.
2. Register that tile format in [`formats.cr`](../formats.cr).

## Writing formats

To get started writing a format file with a tile format class, fill in this template:

```crystal
require "../format_base"

# Tile format for [what the format is].
private class TileFormat_FormatName < Dazzlie::TileFormat
    # Fill out these four with information specific to your format.
    @@description = "Put a short description of what the format is (system, etc.) here."
    @@bytes_per_tile = 192
    @@px_width  = 8
    @@px_height = 8

    # Encodes a tile at (*x*, *y*) in *canvas* to [format]
    # and writes it to the current position in *to*.
    # Returns 1 if a tile was encoded; 0 if not.
    def encode(canvas : StumpyPNG::Canvas, to : IO, x : Int32, y : Int32)
        return 0 if !canvas.includes_pixel? x, y

        # Your encoding logic here.
        # This example encodes a simple format with (r, g, b) bytes for each pixel.
        (y...y + @@px_width).each do |y|
            (x...x + @@px_height).each do |x|
                # If (x, y) goes off the canvas, a pixel should still be encoded.
                color = canvas.safe_get(x, y) || StumpyPNG::RGBA::WHITE
                color.to_rgb8.each { |value| to.write_byte value }
            end
        end

        return 1
    end

    # Decodes a [format] tile from the current position in *from*,
    # and draws it to (*x*, *y*) in *canvas*.
    # Returns 1 if a tile was decoded; 0 if not.
    def decode(from : IO, canvas : StumpyPNG::Canvas, x : Int32, y : Int32)
        tile = Bytes.new @@bytes_per_tile
        bytes_read = from.read tile
        return 0 if bytes_read == 0
        tile_io = IO::Memory.new tile[0, bytes_read]

        # Your decoding logic here.
        # This example decodes a simple format with (r, g, b) bytes for each pixel.
        (y...y + @@px_width).each do |y|
            (x...x + @@px_height).each do |x|
                # If data ends within a tile, it should still be decoded.
                values = Array.new 3 { tile_io.read_byte || 0x00 }
                canvas[x, y] = StumpyPNG::RGBA.from_rgb(values)
            end
        end

        return 1
    end
end

module Dazzlie
    private module Formats
        FormatName = TileFormat_FormatName
    end
end
```

## Registering formats

To register a format, add a line to [`formats.cr`](../formats.cr) that maps a format name to the class you've made. In the case of the above example, if you name it `format_name`, it'd look as following:

```crystal
module Dazzlie
    FORMATS = {
        # A bunch of formats here...
        # The line you add:
        "format_name" => Formats::FormatName
    }
end
```
