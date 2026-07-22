const _SKIP_WRAPPER_HANDLES = Set([
    "ANARILibrary",
    "ANARIDevice",
    "ANARIObject",
    "ANARIFuture",
    "ANARIArray",
])

function _datatype_enum_name(handle_name::AbstractString)
    suffix = handle_name[6:end]
    snake = uppercase(replace(suffix, r"(?<=[a-z])(?=[A-Z])" => "_"))
    return "ANARI_" * snake
end

function _wrapper_name(handle_name::AbstractString)
    return handle_name[6:end]
end

function _kind_name(wrapper_name::AbstractString)
    return wrapper_name * "Kind"
end

function _anari_datatype_enum_names(api::Dict{String,Any})
    for enum in api["enums"]
        enum["name"] == "ANARIDataType" || continue
        return Set(v["name"] for v in enum["values"])
    end
    error("ANARIDataType enum not found in core API")
end

function _collect_wrapper_handles(api::Dict{String,Any})
    enum_names = _anari_datatype_enum_names(api)
    handles = String[]
    for opaque in api["opaqueTypes"]
        name = opaque["name"]
        name in _SKIP_WRAPPER_HANDLES && continue
        parent = get(opaque, "parent", nothing)
        parent == "ANARIObject" || parent == "ANARIArray" || continue
        enum_name = _datatype_enum_name(name)
        enum_name in enum_names || continue
        push!(handles, name)
    end
    return sort(handles)
end

function _collect_new_object_functions(api::Dict{String,Any})
    skip = Set([
        "anariNewDevice",
        "anariNewInitializedDevice",
        "anariNewObject",
    ])
    functions = Dict{String,Dict{String,Any}}()
    for fun in api["functions"]
        name = fun["name"]
        startswith(name, "anariNew") || continue
        name in skip && continue
        functions[fun["returnType"]] = fun
    end
    return functions
end

function _julia_wrapper_arg(c_type::AbstractString, cname::AbstractString)
    cname == "type" && return "subtype", "AbstractString", "subtype"
    jname = julia_argname(cname)
    if c_type == "const void*"
        return jname, "Ptr", "Ptr{Cvoid}($jname)"
    elseif endswith(c_type, "uint64_t")
        return jname, "Integer", "UInt64($jname)"
    else
        return jname, julia_ctype(c_type), jname
    end
end

function _emit_constructor(wrapper_name::AbstractString, kind_name::AbstractString, fun::Dict{String,Any})
    args = fun["arguments"]
    @assert args[1]["type"] == "ANARIDevice"
    arg_names = String[]
    call_args = String["device.handle"]
    for arg in args[2:end]
        jname, jtype, call_arg = _julia_wrapper_arg(arg["type"], arg["name"])
        push!(arg_names, "$jname::$jtype")
        push!(call_args, call_arg)
    end
    fname = fun["name"]
    sig = join(arg_names, ", ")
    call = join(call_args, ", ")
    return """
    function $wrapper_name(device::Device$(isempty(sig) ? "" : ", " * sig))
        handle = $fname($call)
        return Object{$kind_name}(device, handle)
    end
    """
end

function emit_wrappers(api::Dict{String,Any}, path::AbstractString)
    handles = _collect_wrapper_handles(api)
    new_functions = _collect_new_object_functions(api)

    kind_lines = String[]
    alias_lines = String[]
    constructor_lines = String[]
    datatype_lines = String["object_data_type(::Object{UntypedObjectKind}) = ANARI_OBJECT"]

    for handle_name in handles
        wrapper_name = _wrapper_name(handle_name)
        kind_name = _kind_name(wrapper_name)
        enum_name = _datatype_enum_name(handle_name)

        push!(kind_lines, "struct $kind_name <: ObjectKind end")
        push!(alias_lines, "const $wrapper_name = Object{$kind_name}")
        push!(datatype_lines, "object_data_type(::Object{$kind_name}) = $enum_name")

        if haskey(new_functions, handle_name)
            push!(constructor_lines, _emit_constructor(wrapper_name, kind_name, new_functions[handle_name]))
        end
    end

    lines = String[
        GENERATED_HEADER,
        "",
        kind_lines...,
        "",
        join(alias_lines, '\n'),
        "",
        join(datatype_lines, '\n'),
        "",
        constructor_lines...,
    ]

    _write_file(path, join(lines, '\n'))
end
