require "option_parser"
require "./dazzlie"

def error_out(reason)
    STDERR.puts "Error: #{reason}"
    exit 1
end

in_path = nil
out_path = nil

offset = 0
num_tiles = nil

bit_depth = 2
width = nil
height = nil
layout = nil

program_name = PROGRAM_NAME.split('/')[-1]
usage_line = "Usage: #{program_name} <-l layout | -W width | -H height> [other options...]"

details =
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

if ARGV.size == 0
    STDERR.puts %(#{usage_line}\nRun "#{program_name} --help" for more options and info!)
    exit 1
end

OptionParser.parse! do |parser|
    parser.banner = "#{usage_line}\n\nArguments:"
    
    parser.on("-h", "--help", "Show this help and exit.\n") do
        puts parser
        puts
        puts details
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
        "-d DEPTH", "--depth DEPTH",
        "Set the bit depth (either 1 or 2; default 2)."
    ) do |d|
        bit_depth = d.to_i
        raise ArgumentError.new "Invalid bit depth." if !(1 <= bit_depth <= 2)
    rescue ArgumentError
        error_out "Invalid bit depth. Must be either 1 or 2."
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

    parser.on(
        "-l LAYOUT", "--layout LAYOUT",
        %(Set the layout of the tiles - see the "Layout" section.)
    ) do |l|
        layout = l
    rescue ArgumentError
        error_out %(Invalid layout. Run "#{program_name} -h" for help!)
    end
    
    parser.missing_option do |option|
        error_out %(#{option} is missing an argument. Run "#{program_name} -h" for help!)
    end
    parser.invalid_option do |option|
        error_out %(Invalid option: #{option}. Run "#{program_name} -h" for help!)
    end
end

if !(layout || width || height)
    error_out %(No dimensions set! Sey either "--layout", "--width", or "--height".)
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
    decode(in_io, out_io, layout.not_nil!, bit_depth, num_tiles)
rescue e: GraphicsConversionError
    error_out e.message
end

in_io.close  if in_path
out_io.close if out_path
