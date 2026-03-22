module ANARI

using CEnum
using ANARI_SDK_jll

# Include the generated bindings
include("LibANARI.jl")
include("handles.jl")
include("anari_type.jl")

end # module ANARI
