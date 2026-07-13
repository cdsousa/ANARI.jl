const C_PRIMITIVE_JULIA = Dict{String,String}(
    "int" => "Int32",
    "float" => "Float32",
    "double" => "Float64",
    "int8_t" => "Int8",
    "uint8_t" => "UInt8",
    "int16_t" => "Int16",
    "uint16_t" => "UInt16",
    "int32_t" => "Int32",
    "uint32_t" => "UInt32",
    "int64_t" => "Int64",
    "uint64_t" => "UInt64",
)

const C_PRIMITIVE_C = Dict{String,String}(
    "int" => "Cint",
    "float" => "Cfloat",
    "double" => "Cdouble",
    "int8_t" => "Int8",
    "uint8_t" => "UInt8",
    "int16_t" => "Int16",
    "uint16_t" => "UInt16",
    "int32_t" => "Int32",
    "uint32_t" => "UInt32",
    "int64_t" => "Int64",
    "uint64_t" => "UInt64",
)

function _scalar_julia_type(base_type::AbstractString)
    if haskey(C_PRIMITIVE_JULIA, base_type)
        return C_PRIMITIVE_JULIA[base_type]
    elseif base_type == "const char*"
        return "String"
    elseif base_type == "void*"
        return "Ptr{Cvoid}"
    elseif base_type == "void(*)(void)"
        return "Ptr{Cvoid}"
    elseif startswith(base_type, "ANARI")
        return base_type
    else
        return "Any"
    end
end

function _scalar_c_type(base_type::AbstractString)
    if haskey(C_PRIMITIVE_C, base_type)
        return C_PRIMITIVE_C[base_type]
    elseif base_type == "const char*"
        return "Cstring"
    elseif base_type == "void*"
        return "Ptr{Cvoid}"
    elseif base_type == "void(*)(void)"
        return "Ptr{Cvoid}"
    elseif startswith(base_type, "ANARI")
        return base_type
    else
        return "Ptr{Cvoid}"
    end
end

function _value_julia_type(base_type::AbstractString, elements::Int)
    scalar = _scalar_julia_type(base_type)
    return elements == 1 ? scalar : "NTuple{$elements, $scalar}"
end

function _value_c_type(base_type::AbstractString, elements::Int)
    scalar = _scalar_c_type(base_type)
    return elements == 1 ? scalar : "NTuple{$elements, $scalar}"
end

function _datatype_types(
    base_type::AbstractString,
    elements::Int,
    opaque_names::Set{String},
    typedef_names::Set{String},
)
    if elements == 1 && haskey(C_TYPE_MAP, base_type)
        ctype = C_TYPE_MAP[base_type]
        jtype = _scalar_julia_type(base_type)
        return jtype, ctype
    elseif occursin("(*", base_type)
        return "Ptr{Cvoid}", "Ptr{Cvoid}"
    elseif base_type in opaque_names
        return base_type, base_type
    elseif base_type in typedef_names
        return "Ptr{Cvoid}", "Ptr{Cvoid}"
    elseif endswith(base_type, "*")
        ctype = julia_ctype(base_type)
        return "Any", ctype
    else
        return _value_julia_type(base_type, elements), _value_c_type(base_type, elements)
    end
end

function emit_datatypes(api::Dict{String,Any}, path::AbstractString)
    enum = only(filter(e -> e["name"] == "ANARIDataType", api["enums"]))
    opaque_names = Set(o["name"] for o in api["opaqueTypes"])
    typedef_names = Set(t["name"] for t in get(api, "functionTypedefs", Any[]))

    lines = String[
        GENERATED_HEADER,
        "",
        "struct DataTypeInfo",
        "    julia_type::Type",
        "    c_type::Type",
        "    n_components::Int",
        "    normalized::Bool",
        "    base_type::String",
        "end",
        "",
        "const DATATYPE_INFO = Dict{ANARIDataType, DataTypeInfo}(",
    ]

    for value in enum["values"]
        name = value["name"]
        base = value["baseType"]
        elements = value["elements"]
        normalized = value["normalized"]
        jtype, ctype = _datatype_types(base, elements, opaque_names, typedef_names)
        push!(lines, "    $name => DataTypeInfo($jtype, $ctype, $elements, $normalized, $(repr(base))),")
    end

    append!(lines, [
        ")",
        "",
        "datatype_info(type::ANARIDataType) = DATATYPE_INFO[type]",
        "",
        "function julia_type(type::ANARIDataType)",
        "    return DATATYPE_INFO[type].julia_type",
        "end",
        "",
        "function c_type(type::ANARIDataType)",
        "    return DATATYPE_INFO[type].c_type",
        "end",
        "",
        "function datatype_size(type::ANARIDataType)",
        "    return sizeof(DATATYPE_INFO[type].c_type)",
        "end",
        "",
        "function datatype_components(type::ANARIDataType)",
        "    return DATATYPE_INFO[type].n_components",
        "end",
        "",
        "function is_normalized(type::ANARIDataType)",
        "    return DATATYPE_INFO[type].normalized",
        "end",
        "",
    ])

    _write_file(path, join(lines, '\n'))
end
