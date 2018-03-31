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
USAGE_LINE = "Usage: #{ACTUAL_PROGRAM_NAME} <-f format> <-l layout | -W width | -H height> [other options...]"

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
    and graphics will be added in that direction until the end of the data.

    For example, "--layout 'V2 H4 V2 V'" will:
        1. Decode 2 tiles vertically into a 1x2 chunk
        2. Do that 4 times and add those horizontally into a 4x2 chunk
        3. Do that 2 times and add *those* vertically into a 4x4 chunk
        4. Keep adding 4x4 chunks like that vertically until the data ends.
    
    To simply decode an image of specific dimensions and nothing more,
    a layout like "H8 V8" (8x8 tiles) can be used.

    The options "-W" / "--width" and "-H" / "--height" are aliases for
    the layouts "H[width] V" and "V[height] H", respectively.
)

DETAILS = [FORMATS_INFO, LAYOUT_INFO].join("\n\n")

if ARGV.size == 0
    STDERR.puts %(#{USAGE_LINE}\nRun "#{ACTUAL_PROGRAM_NAME} --help" for more options and info!)
    exit 1
end

OptionParser.parse! do |parser|
    parser.banner = "#{USAGE_LINE}\n\nArguments:"
    
    parser.on("-h", "--help", "Show this help and exit.\n") do
        puts parser
        puts
        puts DETAILS
        exit 0
    end

    parser.on("-i PATH", "Input file. If unspecified, " \
              "data will be read from stdin.") { |i| in_path = i }
    parser.on("-o PATH", "Output PNG file. If unspecified, " \
              "data will be sent to stdout.\n") { |o| out_path = o }
    
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
        raise ArgumentError.new "Nonexistent format" if !FORMATS.has_key? format
    rescue ArgumentError
        error_out %(The format "#{f}" doesn't exist. ) \
                  %(Run "#{ACTUAL_PROGRAM_NAME} -h" for a list of available formats!)
    end

    parser.on(
        "-l LAYOUT", "--layout LAYOUT",
        %(Set the layout of the tiles - see the "Layout" section.)
    ) do |l|
        layout = l
    rescue ArgumentError
        error_out %(Invalid layout. Run "#{ACTUAL_PROGRAM_NAME} -h" for help!)
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
    in_io.skip offset
rescue IO::EOFError
end

begin
    decode(in_io, out_io, layout.not_nil!, format.not_nil!, num_tiles)
rescue e : GraphicsConversionError
    error_out e.message.not_nil!
end

in_io.close  if in_path
out_io.close if out_path
