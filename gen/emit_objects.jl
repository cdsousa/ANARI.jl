function _emit_symbol_list(items::AbstractVector)
    isempty(items) && return "Symbol[]"
    syms = join((":$(item)" for item in items), ", ")
    return "[$syms]"
end

function _emit_anari_type_list(items::AbstractVector)
    isempty(items) && return "ANARIDataType[]"
    return "[$(join(items, ", "))]"
end

function _emit_string_list(items::AbstractVector)
    isempty(items) && return "String[]"
    return "[$(join(repr.(items), ", "))]"
end

function _emit_default(value, types=Any[])
    types = [string(t) for t in types]
    value === nothing && return "nothing"
    value isa Bool && return value ? "true" : "false"
    value isa Integer && return string(value)
    value isa AbstractFloat && return string(value, "f0")
    value isa AbstractString && return repr(value)
    if value isa AbstractVector
        float_literals = !isempty(types) && any(t -> occursin("FLOAT", t), types)
        parts = String[]
        for item in value
            if item isa AbstractFloat || float_literals
                push!(parts, string(float(item), "f0"))
            elseif item isa Integer
                push!(parts, string(item))
            elseif item isa AbstractString
                push!(parts, repr(item))
            end
        end
        return "(" * join(parts, ", ") * ")"
    end
    return "nothing"
end

function _object_key(object_type::AbstractString, subtype::Union{Nothing,AbstractString})
    subtype = something(subtype, "")
    return "(ANARI_$object_type, $(repr(subtype)))"
end

function _parse_object_type(object_type::AbstractString)
    startswith(object_type, "ANARI_") && return object_type
    return "ANARI_" * object_type
end

function _emit_parameter_spec(param::Dict{String,Any})
    types = get(param, "types", String[])
    element_types = get(param, "elementType", String[])
    tags = get(param, "tags", String[])
    default = haskey(param, "default") ? param["default"] : nothing
    values = get(param, "values", String[])
    description = get(param, "description", "")
    source = get(param, "sourceExtension", nothing)

    return join([
        "ParameterSpec(",
        repr(param["name"]),
        ", ",
        _emit_anari_type_list(types),
        ", ",
        _emit_symbol_list(tags),
        ", ",
        _emit_default(default, types),
        ", ",
        _emit_string_list(values),
        ", ",
        _emit_anari_type_list(element_types),
        ", ",
        repr(description),
        ", ",
        source === nothing ? "nothing" : repr(source),
        ")",
    ])
end

function _emit_property_spec(prop::Dict{String,Any})
    tags = get(prop, "tags", String[])
    return "PropertySpec($(repr(prop["name"])), $(prop["type"]), $(_emit_symbol_list(tags)))"
end

function emit_objects(api::Dict{String,Any}, path::AbstractString)
    objects = get(api, "objects", Any[])
    attributes = get(api, "attributes", Any[])

    subtypes = Dict{String,Vector{String}}()
    parameter_entries = String[]
    property_entries = String[]

    for obj in objects
        object_type = _parse_object_type(obj["type"])
        subtype = get(obj, "name", "")
        short_type = replace(object_type, "ANARI_" => "")
        key = _object_key(short_type, subtype)

        if !isempty(subtype)
            push!(get!(subtypes, object_type, String[]), subtype)
        end

        params = [_emit_parameter_spec(p) for p in get(obj, "parameters", Any[])]
        if !isempty(params)
            push!(parameter_entries, "    $key => [$(join(params, ", "))],")
        end

        props = [_emit_property_spec(p) for p in get(obj, "properties", Any[])]
        if !isempty(props)
            push!(property_entries, "    $key => [$(join(props, ", "))],")
        end
    end

    attribute_entries = [
        "    $(repr(attr["name"])) => $(attr["type"])," for attr in attributes
    ]

    subtype_entries = [
        "    $object_type => $( _emit_string_list(subtypes[object_type]) ),"
        for object_type in sort(collect(keys(subtypes)))
    ]

    lines = String[
        GENERATED_HEADER,
        "",
        "struct ParameterSpec",
        "    name::String",
        "    types::Vector{ANARIDataType}",
        "    tags::Vector{Symbol}",
        "    default::Any",
        "    values::Vector{String}",
        "    element_types::Vector{ANARIDataType}",
        "    description::String",
        "    source_extension::Union{Nothing,String}",
        "end",
        "",
        "struct PropertySpec",
        "    name::String",
        "    type::ANARIDataType",
        "    tags::Vector{Symbol}",
        "end",
        "",
        "const OBJECT_SUBTYPES = Dict{ANARIDataType, Vector{String}}(",
        subtype_entries...,
        ")",
        "",
        "const OBJECT_PARAMETERS = Dict{Tuple{ANARIDataType, String}, Vector{ParameterSpec}}(",
        parameter_entries...,
        ")",
        "",
        "const OBJECT_PROPERTIES = Dict{Tuple{ANARIDataType, String}, Vector{PropertySpec}}(",
        property_entries...,
        ")",
        "",
        "const ATTRIBUTES = Dict{String, ANARIDataType}(",
        attribute_entries...,
        ")",
        "",
        "object_subtypes(object_type::ANARIDataType) = get(OBJECT_SUBTYPES, object_type, String[])",
        "",
        "function parameter_specs(object_type::ANARIDataType, subtype::AbstractString = \"\")",
        "    return get(OBJECT_PARAMETERS, (object_type, String(subtype)), ParameterSpec[])",
        "end",
        "",
        "function property_specs(object_type::ANARIDataType, subtype::AbstractString = \"\")",
        "    return get(OBJECT_PROPERTIES, (object_type, String(subtype)), PropertySpec[])",
        "end",
        "",
        "function parameter_spec(",
        "    object_type::ANARIDataType,",
        "    subtype::AbstractString,",
        "    name::AbstractString,",
        ")",
        "    for spec in parameter_specs(object_type, subtype)",
        "        spec.name == name && return spec",
        "    end",
        "    return nothing",
        "end",
        "",
        "is_required(spec::ParameterSpec) = :required in spec.tags",
        "",
    ]

    _write_file(path, join(lines, '\n'))
end
