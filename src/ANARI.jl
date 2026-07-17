module ANARI

include("generated/Generated.jl")
using .Generated
using .Generated.LibANARI

include("set_parameter_safe.jl")

export LibANARI
export set_parameter_safe

end # module ANARI
