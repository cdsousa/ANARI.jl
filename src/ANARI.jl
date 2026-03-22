module ANARI

using CEnum
using ANARI_SDK_jll

# Include the generated bindings
include("LibANARI.jl")
include("handles.jl")
include("parameters.jl")
include("render.jl")
include("arrays.jl")
include("anari_type.jl")

end # module ANARI
