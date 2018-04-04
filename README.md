# ✨ Dazzlie

**Dazzlie** is a command-line program that lets you convert between various retro tile graphics formats and PNG. That means you can decode tile graphics to a PNG that's easy to work with, and then encode it back to the original format again.

One of Dazzlie's main draws is its unique [layout system](#layouts), which lets you lay out the tiles you encode or decode however you want. Never again will you have to edit sprites with their tiles all shuffled around!

Dazzlie lets you do a whole bunch of cool stuff:

* Extract sprites and other graphics from ROMs, and hack them back in just by editing a PNG
* Put your graphics into PNGs when writing a retro game in assembly (with [RGBDS](https://github.com/rednex/rgbds), for example)
* Make your disassembly tidy, pretty, and easy to understand by putting the game's graphics in PNGs

Dazzlie is system-agnostic – it can be extended to work with graphics from pretty much any old console you'd like! For a list of currently supported formats, see the *[Formats](#formats)* section.

## How to install

Dazzlie is written in [Crystal](https://crystal-lang.org/), so first of all you'll need to install the Crystal compiler. Check out [the official installation instructions](https://crystal-lang.org/docs/installation/) if you don't already have it! At the time of writing, Crystal isn't available natively for Windows, so if you're on Windows you'll need to use [WSL](https://docs.microsoft.com/en-us/windows/wsl/install-win10) (available on Windows 10).

Once that's all done, simply clone the Dazzlie repo and run `make install`:

```bash
git clone https://github.com/obskyr/dazzlie.git
cd dazzlie && sudo make install
```

And presto! You'll be able to run `dazzlie` anywhere you want. If you just want to build, and not install, run `make` instead of `make install` and you'll find the compiled program at `bin/dazzlie`.

## How to use

The commands you'll be using are `dazzlie encode` (PNG to tile data) and `dazzlie decode` (tile data to PNG). When you convert something, you need to specify a format (`-f` or `--format`) and a [layout](#layouts) (`-l` or `--layout`, or the width or height options) You can then either specify input and output files with `-i` and `-o`, or you can pipe data into stdin and out from stdout.

Here are some examples:

```bash
# Encode tiles consecutively from font.png into 1BPP Game Boy
# tiles and output the resulting tile data to font.2bpp.
$ dazzlie encode -f gb_1bpp -l "H" -i font.png -o font.2bpp

# Decode a 4×4-tile 2BPP Game Boy graphic from address 0x10A8B4 in
# crystal.gbc and output the decoded PNG to igglybuff.png.
$ dazzlie decode -f gb_2bpp -l "H4 V4" -a 0x10A8B4 -i crystal.gbc -o igglybuff.png

# Pipe data 2BPP Game Boy tile data into Dazzlie, decode it in the order
# of the supplied layout, and pipe the output PNG data to howdy.png.
# For information on how the layout works, see the "Layouts" section.
$ cat howdy.2bpp | dazzlie decode -f gb_2bpp -l "V2 H4 V2 H8 V" > howdy.png
```

Additional options are:
* `-h`, `--help`: Show help on how to use Dazzlie. This includes a list of arguments, a list of available formats, and information on layouts.
* `-W WIDTH`, `--width WIDTH`: Set the width of the graphic and add tiles horizontally. Equivalent to the layout `H[WIDTH] V`. Will continue until the end of the data / image if `--numtiles` isn't set.
* `-H HEIGHT`, `--height HEIGHT`: Set the height of the graphic and add tiles vertically. Equivalent to the layout `V[HEIGHT] H`. Will consume all the tiles in the input if `--numtiles` isn't set.
* `-a ADDRESS`, `--address ADDRESS`: When decoding, specify the offset in the input file to start decoding at, and when using `--patch`, the offset in the output file to apply the patch at.
* `-n TILES`, `--numtiles TILES`: Stop after `TILES` tiles have been encoded / decoded.
* `--patch`: When encoding, patch an existing file with the output data instead of writing a new file.

For more details on how options work, run `dazzlie --help`.

## Formats

Dazzlie currently supports tile graphics in the following formats:

* Game Boy and Game Boy Color
    * `gb_2bpp`: tiles at 2 bits per pixel.
    * `gb_1bpp`: tiles at 1 bit per pixel.
    * `gb_rows_2bpp`: sub-tile 8×1 rows at 2 bits per pixel. Useful for graphics with heights that don't align to tiles.
    * `gb_rows_2bpp`: sub-tile 8×1 rows at 1 bit per pixel.

…That's only formats for *one* system at the moment, isn't it. Dazzlie is easily extensible, though! If there's a format you're missing, fork this repo, [add your own format](src/formats), and make a pull request! If you don't feel up to coding it yourself, you can [open an issue about it](https://github.com/obskyr/khinsider/issues) and I might just implement it for you.

## Layouts

Tiles are often arranged a bit oddly in memory in old games. In order to lay tiles out as you want, you describe layouts using the `-l` or `--layout` option. A Dazzlie layout is expressed as list of direction-length pairs.

Direction-length pairs looks something like `H8` (8 horizontally) or `V2` (2 vertically). They consist of a direction ("H" or "V" for horizontal or vertical) and then a length. Each pair depends on the previous one - the first pair specifies which direction to add tiles and how many, and the next specifies which direction to stack those "chunks" and how many. The one after that specifies how to stack *those*, and so on.

Optionally, the last pair can leave the length out (just be `H` or `V`) and thus make the layout "infinite": graphics will be added in that direction until the end of the input. When encoding (converting PNG to data), infinite layouts will wrap - when a row (for infinite horizontal layouts) or column (for infinite vertical layouts) ends, graphics will continue to be added from the next one until the end of the image.

Here's an example! `--layout "V2 H4 V2 V"` will:
1. Add 2 tiles vertically in a 1×2-tile chunk
2. Do that 4 times and add those horizontally into a 4×2 chunk
3. Do that 2 times and add *those* vertically into a 4×4 chunk
4. Keep adding 4x4 chunks like that vertically (and, if encoding, go through all the 4-tile-wide columns) until the end of the input.

Here are examples of a few simple, useful layouts, for when you don't need anything special:
* `"H"` or  `"V"`: When encoding, these let you simply encode all tiles in left-to-right or top-to-bottom order, going through all the rows or columns in the image.
* `"H8 V8"` or `"V8 H8"`: These let you simply decode an image of a fixed size. `"H8 V8"` adds tiles in rows; `"V8 H8"` adds them in columns.
* `"H4 V4 V8"`: Useful for when animations are stored as contiguous sprites in memory. This one would be 8 frames of a 4×4-tile sprite, arranged vertically in the PNG.

# Contact

If you've found a bug in Dazzlie, or there's a feature or a format you want, you can [open an issue here on GitHub](https://github.com/obskyr/khinsider/issues) and I'll do my best to address it!

If you've got any questions – or if you'd just like to talk about whatever, really – you can easily get to me in these ways:

* [@obskyr](https://Twitter.com/obskyr) on Twitter!
* [E-mail](mailto:powpowd@gmail.com) me!

If you're using Dazzlie for something, I'd love to hear from you.

Enjoy! 😄✨
