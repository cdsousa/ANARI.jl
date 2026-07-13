#!/usr/bin/env julia
# Run from the package root: julia --project -e 'include("gen/run.jl")'

using JSON

include("merge.jl")
include("c_types.jl")
include("emit_core.jl")
include("emit_datatypes.jl")
include("emit_objects.jl")

const API_DIR = joinpath(@__DIR__, "api")
const OUT_DIR = joinpath(@__DIR__, "..", "src", "generated")

function main()
    core_api = merge_api(API_DIR, :core)
    objects_api = merge_api(API_DIR, :objects)
    _merge_enums!(core_api["enums"], get(objects_api, "enums", Any[]))
    if haskey(objects_api, "functionTypedefs")
        existing = Set(t["name"] for t in core_api["functionTypedefs"])
        for typedef in objects_api["functionTypedefs"]
            typedef["name"] in existing && continue
            push!(core_api["functionTypedefs"], typedef)
        end
    end

    @info "Loaded core API" enums=length(core_api["enums"]) functions=length(core_api["functions"])
    @info "Loaded object metadata" objects=length(get(objects_api, "objects", Any[]))

    emit_core(core_api, OUT_DIR)
    emit_datatypes(core_api, joinpath(OUT_DIR, "datatypes.jl"))
    emit_objects(objects_api, joinpath(OUT_DIR, "objects.jl"))
    emit_generated_module(OUT_DIR)

    @info "Generated Julia sources" OUT_DIR
end

main()
