using Clang.Generators
using ANARI_SDK_jll

# Locate the headers
artifact_dir = dirname(dirname(ANARI_SDK_jll.libanari))
include_dir = joinpath(artifact_dir, "include")
anari_dir = joinpath(include_dir, "anari")

# The main header that includes everything we need
headers = [joinpath(anari_dir, "anari.h")]

# Generator options
options = load_options(joinpath(@__DIR__, "generator.toml"))

# Add the artifact include directory so Clang can find sub-headers
args = get_default_args()
push!(args, "-I$include_dir")
# Force C mode to avoid C++ constructs (the header has an #ifdef __cplusplus guard)
push!(args, "-xc")
push!(args, "-std=c99")

ctx = create_context(headers, args, options)

build!(ctx)
