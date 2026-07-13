# Port of ANARI-SDK code_gen/merge_anari.py

function _check_conflicts(a, b, key::AbstractString, scope::AbstractString)
    a_set = Set(get(x, key, nothing) for x in a)
    b_set = Set(get(x, key, nothing) for x in b)
    conflicts = intersect(a_set, b_set)
    for conflict in conflicts
        entries = [x for x in a if get(x, key) == conflict]
        append!(entries, (x for x in b if get(x, key) == conflict))
        @warn "duplicate $key while merging $scope" conflict entries
    end
    return nothing
end

function _merge_enums!(core, extension)
    for enum in extension
        name = enum["name"]
        idx = findfirst(x -> x["name"] == name, core)
        if idx === nothing
            push!(core, enum)
        else
            c = core[idx]
            _check_conflicts(c["values"], enum["values"], "name", name)
            _check_conflicts(c["values"], enum["values"], "value", name)
            append!(c["values"], enum["values"])
        end
    end
    return nothing
end

function _merge_parameters!(core, extension)
    for param in extension
        name = param["name"]
        idx = findfirst(x -> x["name"] == name, core)
        if idx === nothing
            push!(core, param)
        else
            c = core[idx]
            if haskey(c, "types") && haskey(param, "types")
                append!(c["types"], param["types"])
            end
            if haskey(c, "values") && haskey(param, "values")
                append!(c["values"], param["values"])
            end
        end
    end
    return nothing
end

function _merge_objects!(core, extension)
    for (field, value) in extension
        if field == "parameters"
            _merge_parameters!(core["parameters"], value)
        elseif haskey(core, field)
            if value isa AbstractVector && core[field] isa AbstractVector
                append!(core[field], value)
            elseif field != "sourceExtension"
                core[field] = value
            end
        else
            core[field] = value
        end
    end
    return nothing
end

function _merge_object_table!(core, extension, wildcard::AbstractString = "")
    for obj in extension
        if haskey(obj, "name") && obj["name"] != wildcard
            name = obj["name"]
            kind = obj["type"]
            idx = findfirst(x -> x["type"] == kind && haskey(x, "name") && x["name"] == name, core)
            if idx === nothing
                push!(core, obj)
            else
                _merge_objects!(core[idx], obj)
            end
        else
            kind = obj["type"]
            idx = findfirst(x -> x["type"] == kind, core)
            if idx === nothing
                push!(core, obj)
            else
                _merge_objects!(core[idx], obj)
            end
        end
    end
    return nothing
end

function merge_api!(core::Dict{String,Any}, extension::Dict{String,Any}; verbose::Bool = false)
    if !haskey(core, "extensions")
        core["extensions"] = String[]
    end
    if get(core["info"], "type", "") == "extension" &&
       haskey(core["info"], "name") &&
       !(core["info"]["name"] in core["extensions"])
        push!(core["extensions"], core["info"]["name"])
    end

    for (k, v) in extension
        if !haskey(core, k)
            core[k] = deepcopy(v)
        elseif k == "info"
            if verbose && haskey(v, "type") && haskey(v, "name")
                @info "merging $(v["type"]) $(v["name"])"
            end
            if haskey(v, "name") && get(v, "type", "") == "extension" && !(v["name"] in core["extensions"])
                push!(core["extensions"], v["name"])
            end
        elseif k == "enums"
            _merge_enums!(core[k], v)
        elseif k == "descriptions"
            append!(core, v)
        elseif k == "objects"
            _merge_object_table!(core[k], v)
        else
            _check_conflicts(core[k], v, "name", k)
            append!(core[k], v)
        end
    end
    return core
end

function tag_extension!(tree::Dict{String,Any})
    info = get(tree, "info", Dict{String,Any}())
    if get(info, "type", "") != "extension" || !haskey(info, "name")
        return tree
    end
    extension = info["name"]
    for obj in get(tree, "objects", Any[])
        obj["sourceExtension"] = extension
        for param in get(obj, "parameters", Any[])
            param["sourceExtension"] = extension
        end
    end
    return tree
end

function crawl_dependencies(root::Dict{String,Any}, json_paths::Vector{<:AbstractString})
    deps = String[]
    append!(deps, reverse(copy(get(get(root, "info", Dict()), "dependencies", String[]))))
    i = 1
    while i <= length(deps)
        dep = deps[i]
        i += 1
        match_idx = findfirst(p -> startswith(basename(p), dep * "."), json_paths)
        match_idx === nothing && continue
        dep_tree = JSON.parsefile(json_paths[match_idx])
        dep_info = get(dep_tree, "info", Dict{String,Any}())
        for nested in reverse(get(dep_info, "dependencies", String[]))
            nested == "anari_core_1_0" && continue
            push!(deps, nested)
        end
    end
    seen = Set{String}()
    return [dep for dep in reverse(deps) if !(dep in seen) && (push!(seen, dep); true)]
end

function merge_api(api_dir::AbstractString, profile::Symbol)
    json_paths = filter(f -> endswith(f, ".json"), readdir(joinpath(api_dir); join=true))
    if profile == :core
        core_path = joinpath(api_dir, "anari_core_1_0.json")
        return JSON.parsefile(core_path; dicttype=Dict{String,Any})
    elseif profile == :objects
        meta_path = joinpath(api_dir, "anari_core_objects_all_1_0.json")
        core = JSON.parsefile(meta_path; dicttype=Dict{String,Any})
        for dep in crawl_dependencies(core, json_paths)
            dep_path = joinpath(api_dir, "$dep.json")
            isfile(dep_path) || error("missing dependency JSON: $dep_path")
            merge_api!(core, JSON.parsefile(dep_path; dicttype=Dict{String,Any}))
        end
        return core
    else
        error("unknown profile: $profile")
    end
end
