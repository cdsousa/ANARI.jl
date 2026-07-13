# Map C type strings from ANARI SDK JSON to Julia ccall types.

const C_TYPE_MAP = Dict{String,String}(
    "void" => "Cvoid",
    "void*" => "Ptr{Cvoid}",
    "const void*" => "Ptr{Cvoid}",
    "const char*" => "Cstring",
    "const char**" => "Ptr{Ptr{Cchar}}",
    "const char **" => "Ptr{Ptr{Cchar}}",
    "int" => "Cint",
    "int8_t" => "Int8",
    "uint8_t" => "UInt8",
    "int16_t" => "Int16",
    "uint16_t" => "UInt16",
    "int32_t" => "Int32",
    "uint32_t" => "UInt32",
    "int64_t" => "Int64",
    "uint64_t" => "UInt64",
    "uint32_t*" => "Ptr{UInt32}",
    "uint64_t*" => "Ptr{UInt64}",
    "int" => "Cint",
    "float" => "Cfloat",
    "double" => "Cdouble",
)

function julia_ctype(c_type::AbstractString)
    if haskey(C_TYPE_MAP, c_type)
        return C_TYPE_MAP[c_type]
    end
    if endswith(c_type, "*")
        base = chop(c_type)
        base = startswith(base, "const ") ? strip(base[7:end]) : base
        if base == "ANARIDataType"
            return "Ptr{ANARIDataType}"
        end
        return "Ptr{$base}"
    end
    return c_type
end

const JULIA_KEYWORDS = Set{String}([
    "baremodule", "begin", "break", "catch", "const", "continue", "do", "else",
    "elseif", "end", "export", "false", "finally", "for", "function", "global",
    "if", "import", "let", "local", "macro", "module", "quote", "return",
    "struct", "true", "try", "using", "while", "mutable", "abstract", "where",
])

function julia_argname(name::AbstractString)
    return name in JULIA_KEYWORDS ? "var\"$name\"" : name
end

function julia_struct_member_type(c_type::AbstractString)
    mapped = julia_ctype(c_type)
    mapped == "Cstring" && return "Ptr{Cchar}"
    return mapped
end
