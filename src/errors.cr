module Dazzlie
    # Shim until the Crystal version aftser 0.24.2 comes out.
    class NotImplementedError < Exception
    end

    class GraphicsConversionError < ArgumentError
    end
end
