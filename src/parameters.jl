export setparam!, commit!

function _as_anari_object(object::Device)
    return object.ptr
end

function _as_anari_object(object::ANARIObjectHandle)
    return object.ptr
end

function _check_object_dtype(dtype::LibANARI.ANARIDataType)
    return dtype in (
        LibANARI.ANARI_ARRAY1D,
        LibANARI.ANARI_DEVICE,
        LibANARI.ANARI_OBJECT,
        LibANARI.ANARI_CAMERA,
        LibANARI.ANARI_FRAME,
        LibANARI.ANARI_GEOMETRY,
        LibANARI.ANARI_GROUP,
        LibANARI.ANARI_INSTANCE,
        LibANARI.ANARI_LIGHT,
        LibANARI.ANARI_MATERIAL,
        LibANARI.ANARI_RENDERER,
        LibANARI.ANARI_SURFACE,
        LibANARI.ANARI_WORLD,
    )
end

function _prepare_parameter_ref(dtype::LibANARI.ANARIDataType, value)
    if dtype == LibANARI.ANARI_BOOL
        return Ref{UInt32}(value ? 1 : 0)
    elseif dtype == LibANARI.ANARI_INT32
        return Ref{Int32}(Int32(value))
    elseif dtype == LibANARI.ANARI_UINT32
        return Ref{UInt32}(UInt32(value))
    elseif dtype == LibANARI.ANARI_FLOAT32
        return Ref{Float32}(Float32(value))
    elseif dtype == LibANARI.ANARI_FLOAT64
        return Ref{Float64}(Float64(value))
    elseif dtype == LibANARI.ANARI_UINT32_VEC2
        tuple_value = convert(NTuple{2, UInt32}, value)
        return Ref{NTuple{2, UInt32}}(tuple_value)
    elseif dtype == LibANARI.ANARI_FLOAT32_VEC2
        tuple_value = convert(NTuple{2, Float32}, value)
        return Ref{NTuple{2, Float32}}(tuple_value)
    elseif dtype == LibANARI.ANARI_FLOAT32_VEC3
        tuple_value = convert(NTuple{3, Float32}, value)
        return Ref{NTuple{3, Float32}}(tuple_value)
    elseif dtype == LibANARI.ANARI_FLOAT32_VEC4
        tuple_value = convert(NTuple{4, Float32}, value)
        return Ref{NTuple{4, Float32}}(tuple_value)
    elseif _check_object_dtype(dtype)
        value isa ANARIHandle || throw(ArgumentError("value must be an ANARIHandle for object dtypes"))
        return Ref{LibANARI.ANARIObject}(_as_anari_object(value))
    end

    throw(ArgumentError("unsupported ANARIDataType in setparam!: $dtype"))
end

function setparam!(
    device::Device,
    object::Union{Device, ANARIObjectHandle},
    name::AbstractString,
    dtype::LibANARI.ANARIDataType,
    value,
)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    object_ptr = _as_anari_object(object)
    _isnull(object_ptr) && throw(ArgumentError("target object handle has already been released"))

    value_ref = _prepare_parameter_ref(dtype, value)
    GC.@preserve value_ref begin
        LibANARI.anariSetParameter(
            device.ptr,
            object_ptr,
            name,
            dtype,
            Base.unsafe_convert(Ptr{Cvoid}, value_ref),
        )
    end
    return object
end

function commit!(device::Device, object::Union{Device, ANARIObjectHandle})
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    object_ptr = _as_anari_object(object)
    _isnull(object_ptr) && throw(ArgumentError("target object handle has already been released"))

    LibANARI.anariCommitParameters(device.ptr, object_ptr)
    return object
end
