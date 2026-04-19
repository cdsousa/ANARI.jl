using Clang.Generators
using ANARI_SDK_jll

artifact_dir = dirname(dirname(ANARI_SDK_jll.libanari))
include_dir = joinpath(artifact_dir, "include")
anari_dir = joinpath(include_dir, "anari")

headers = [joinpath(anari_dir, "anari.h")]

options = load_options(joinpath(@__DIR__, "generator.toml"))

args = get_default_args()
push!(args, "-I$include_dir")
push!(args, "-xc")
push!(args, "-std=c99")

ctx = create_context(headers, args, options)

build!(ctx)
