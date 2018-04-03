require "option_parser"
require "./dazzlie"

include Dazzlie

def error_out(reason : String)
    header = "Error: "
    reason = reason.gsub('\n', "\n#{" " * header.size}")
    STDERR.puts "#{header}#{reason}"
    exit 1
end

in_path = nil
out_path = nil

offset = 0
num_tiles = nil

format = nil
layout = nil
width = nil
height = nil

ACTUAL_PROGRAM_NAME = PROGRAM_NAME.split('/')[-1]
USAGE_LINE = "Usage: #{ACTUAL_PROGRAM_NAME} <encode | decode> <-f format> <-l layout | -W width | -H height> [other options...]"

DESCRIPTION =
%(Dazzlie lets you convert between various tile graphics formats and PNG!
"#{ACTUAL_PROGRAM_NAME} encode" converts PNG to tile data, and "#{ACTUAL_PROGRAM_NAME} decode" does the opposite.)

EXAMPLES =
%(Examples:
    #{ACTUAL_PROGRAM_NAME} decode -f gb_2bpp -l "H4 V4" -p 0x10A8B4 -i crystal.gbc -o igglybuff.png
    #{ACTUAL_PROGRAM_NAME} encode -f gb_1bpp -W 16 -n 256 -i font.png -o font.2bpp
    cat howdy.2bpp | #{ACTUAL_PROGRAM_NAME} decode -f gb_2bpp -l "V2 H4 V2 H8 V10" > howdy.png)

MAX_FORMAT_NAME_LENGTH = FORMATS.keys.map{ |s| s.size }.max
FORMATS_INFO = "Formats:\n" + FORMATS.each.join '\n' do |name, cls|
    name = name + ":"
    "    #{name.ljust(MAX_FORMAT_NAME_LENGTH + 1)} #{cls.description} Tiles are #{cls.px_width}x#{cls.px_height} pixels."
end

LAYOUT_INFO =
%(Layout:
    In order to lay tiles out as you want, you can describe layouts using
    the "-l" / "--layout" option. Set it to a list of direction-length pairs.
    
    Direction-length pairs look something like "H8" (8 horizontally) or
    "V2" (2 vertically). They consist of a direction ("H" or "V" for
    horizontal or vertical) and then a length. Each pair depends on the
    previous one - the first pair specifies which direction to add tiles
    and how many, and the next specifies which direction to stack those
    "chunks" and how many. The one after that specifies how to stack *those*,
    and so on.

    Optionally, the last pair can leave the length out (just be "H" or "V")
    and thus make the layout "infinite": graphics will be added in that
    direction until the end of the data/image. When encoding (converting PNG
    to data), infinite layouts will wrap - when a row/column ends, graphics
    will continue to be added from the next one until the end of the image.

    For example, "--layout 'V2 H4 V2 V'" will:
        1. Add 2 tiles vertically in a 1x2 chunk
        2. Do that 4 times and add those horizontally into a 4x2 chunk
        3. Do that 2 times and add *those* vertically into a 4x4 chunk
        4. Keep adding 4x4 chunks like that vertically (and, if encoding, go
           through all the 4-tile-wide columns) until the data/image ends.
    
    To simply encode all tiles in linear order, you can use the layouts "H"
    (all tiles in the image horizontally) or "V" (the same but vertically).
    
    To simply decode an image of specific dimensions and nothing more,
    a layout like "H8 V8" (8x8 tiles) can be used.

    The options "-W" / "--width" and "-H" / "--height" are aliases for
    the layouts "H[width] V" and "V[height] H", respectively.)

DETAILS = [FORMATS_INFO, LAYOUT_INFO].join("\n\n")

if ARGV.size == 0
    STDERR.puts %(#{USAGE_LINE}\nRun "#{ACTUAL_PROGRAM_NAME} --help" for more options and info!)
    exit 1
end

OptionParser.parse! do |parser|
    parser.banner = "#{USAGE_LINE}\n\n#{DESCRIPTION}\n\n#{EXAMPLES}\n\nArguments:"
    
    parser.on("-h", "--help", "Show this help and exit.\n") do
        puts parser
        puts
        puts DETAILS
        exit 0
    end

    parser.on("-i PATH", "Input file. If unspecified, " \
              "data will be read from stdin.") { |i| in_path = i }
    parser.on("-o PATH", "Output PNG file. If unspecified, " \
              "data will be written to stdout.\n") { |o| out_path = o }
    
    parser.on(
        "-p POSITION", "--position POSITION",
        "The offset to start decoding at. Default 0."
    ) do |p|
        offset = p.to_i(prefix: true)
    rescue ArgumentError
        error_out "Invalid position. Set it to a number!"
    end

    parser.on(
        "-n TILES", "--numtiles TILES",
        "How many tiles to decode.\n"
    ) do |n|
        num_tiles = n.to_i(prefix: true)
    rescue ArgumentError
        error_out "Invalid number of tiles. Set it to a number!"
    end
    
    parser.on(
        "-f FORMAT", "--format FORMAT",
        %(Set the graphics format to use - see the "Formats" section.)
    ) do |f|
        format = f
        if !FORMATS.has_key? format
            error_out %(The format "#{f}" doesn't exist. ) \
                      %(Run "#{ACTUAL_PROGRAM_NAME} -h" for a list of available formats!)
        end
    end

    parser.on(
        "-l LAYOUT", "--layout LAYOUT",
        %(Set the layout of the tiles - see the "Layout" section.)
    ) do |l|
        layout = l
    end

    parser.on(
        "-W WIDTH", "--width WIDTH",
        "Add tiles horizontally and wrap to the next row after WIDTH tiles."
    ) do |w|
        width = w.to_i(prefix: true)
    rescue ArgumentError
        error_out "Invalid width. Set it to a number!"
    end

    parser.on(
        "-H HEIGHT", "--height HEIGHT",
        "Add tiles vertically and wrap to the next column after HEIGHT tiles."
    ) do |h|
        height = h.to_i(prefix: true)
    rescue ArgumentError
        error_out "Invalid height. Set it to a number!"
    end
    
    parser.missing_option do |option|
        error_out %(#{option} is missing an argument. Run "#{ACTUAL_PROGRAM_NAME} -h" for help!)
    end
    parser.invalid_option do |option|
        error_out %(Invalid option: #{option}. Run "#{ACTUAL_PROGRAM_NAME} -h" for help!)
    end
end

if ARGV.size == 1
    command = ARGV[0].downcase
    if !["encode", "decode"].includes? command
        error_out %(The command "#{command}" is invalid - valid commands are "encode" and "decode".)
    end
elsif ARGV.size == 0
    error_out %(No command specified! Please specify either "encode" or "decode".)
else
    error_out %(Too many positional arguments! As sole positional argument, specify "encode" or "decode".)
end

if !format
    error_out %(No format set! ) \
              %(Set "-f" or "--format" to the graphics format you're working with.\n) \
              %(Run "#{ACTUAL_PROGRAM_NAME} --help" for a list of formats.")
end

if !(layout || width || height)
    error_out %(No dimensions set! Set either "--layout", "--width", or "--height".)
end

if layout && (width || height) 
    error_out "Can't set both layout and width/height."
end

if width && height
    error_out %(Can't set both width and height options at the same time.\n) \
              %(Use a --layout of either "H#{width} V#{height}" (rows) or ) \
              %("V#{height} H#{width}" (columns), depending on which you want!)
end

if width
    layout = "H#{width} V"
elsif height
    layout = "V#{height} H"
end

input_specified = in_path || !STDIN.tty?
output_specified = out_path || !STDOUT.tty?
if !input_specified | !output_specified
    unspecified = [] of String
    unspecified.push "input" if !input_specified
    unspecified.push "output" if !output_specified
    message = "No #{unspecified.join(" or ")} specified."
    if !input_specified
        message += %(\nFor input, either set the "-i" option or pipe data into stdin.)
    end
    if !output_specified
        message += %(\nFor output, either set the "-o" option or pipe data from stdout.)
    end
    error_out message
end

if path = in_path
    begin
        in_io = File.open path, "rb"
    rescue Errno
        error_out "Couldn't open #{in_path} for reading."
    end
else
    in_io = STDIN
end

if path = out_path
    begin
        out_io = File.open path, "wb"
    rescue Errno
        error_out "Couldn't open #{out_path} for writing."
    end
else
    STDOUT.flush_on_newline = false
    out_io = STDOUT
end

begin
    if command == "encode"
        encode(in_io, out_io, layout.not_nil!, format.not_nil!, num_tiles)
    else
        begin
            in_io.skip offset
        rescue IO::EOFError
        end
        decode(in_io, out_io, layout.not_nil!, format.not_nil!, num_tiles)
    end
rescue e : GraphicsConversionError
    error_out e.message.not_nil!
end

in_io.close  if in_path
out_io.close if out_path
