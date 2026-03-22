export ANARIHandle, Library, Device, World, Frame, Camera, Renderer, release!, setparam!, commit!

abstract type ANARIHandle end

_isnull(ptr::Ptr) = ptr == C_NULL

function _require_nonnull(ptr::Ptr, what::AbstractString)
    _isnull(ptr) && throw(ErrorException("$what returned a null handle"))
    return ptr
end

mutable struct Library <: ANARIHandle
    ptr::LibANARI.ANARILibrary

    function Library(ptr::LibANARI.ANARILibrary)
        _require_nonnull(ptr, "anariLoadLibrary")
        obj = new(ptr)
        finalizer(obj) do lib
            try
                release!(lib)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Device <: ANARIHandle
    ptr::LibANARI.ANARIDevice
    library::Library

    function Device(ptr::LibANARI.ANARIDevice, library::Library)
        _require_nonnull(ptr, "anariNewDevice")
        obj = new(ptr, library)
        finalizer(obj) do dev
            try
                release!(dev)
            catch
                nothing
            end
        end
        return obj
    end
end

abstract type ANARIObjectHandle <: ANARIHandle end

mutable struct World <: ANARIObjectHandle
    ptr::LibANARI.ANARIWorld
    device::Device

    function World(ptr::LibANARI.ANARIWorld, device::Device)
        _require_nonnull(ptr, "anariNewWorld")
        obj = new(ptr, device)
        finalizer(obj) do world
            try
                release!(world)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Frame <: ANARIObjectHandle
    ptr::LibANARI.ANARIFrame
    device::Device

    function Frame(ptr::LibANARI.ANARIFrame, device::Device)
        _require_nonnull(ptr, "anariNewFrame")
        obj = new(ptr, device)
        finalizer(obj) do frame
            try
                release!(frame)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Camera <: ANARIObjectHandle
    ptr::LibANARI.ANARICamera
    device::Device

    function Camera(ptr::LibANARI.ANARICamera, device::Device)
        _require_nonnull(ptr, "anariNewCamera")
        obj = new(ptr, device)
        finalizer(obj) do camera
            try
                release!(camera)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Renderer <: ANARIObjectHandle
    ptr::LibANARI.ANARIRenderer
    device::Device

    function Renderer(ptr::LibANARI.ANARIRenderer, device::Device)
        _require_nonnull(ptr, "anariNewRenderer")
        obj = new(ptr, device)
        finalizer(obj) do renderer
            try
                release!(renderer)
            catch
                nothing
            end
        end
        return obj
    end
end

function Library(name::AbstractString)
    ptr = LibANARI.anariLoadLibrary(name, C_NULL, C_NULL)
    return Library(ptr)
end

function Device(library::Library, subtype::AbstractString)
    _isnull(library.ptr) && throw(ArgumentError("library handle has already been released"))
    ptr = LibANARI.anariNewDevice(library.ptr, subtype)
    return Device(ptr, library)
end

function World(device::Device)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewWorld(device.ptr)
    return World(ptr, device)
end

function Frame(device::Device)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewFrame(device.ptr)
    return Frame(ptr, device)
end

function Camera(device::Device, subtype::AbstractString)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewCamera(device.ptr, subtype)
    return Camera(ptr, device)
end

function Renderer(device::Device, subtype::AbstractString)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewRenderer(device.ptr, subtype)
    return Renderer(ptr, device)
end

function release!(library::Library)
    _isnull(library.ptr) && return nothing
    LibANARI.anariUnloadLibrary(library.ptr)
    library.ptr = LibANARI.ANARILibrary(C_NULL)
    return nothing
end

function release!(device::Device)
    _isnull(device.ptr) && return nothing
    LibANARI.anariRelease(device.ptr, device.ptr)
    device.ptr = LibANARI.ANARIDevice(C_NULL)
    return nothing
end

function release!(object::ANARIObjectHandle)
    _isnull(object.ptr) && return nothing
    _isnull(object.device.ptr) || LibANARI.anariRelease(object.device.ptr, object.ptr)
    object.ptr = Ptr{Cvoid}(C_NULL)
    return nothing
end

function _as_anari_object(object::Device)
    return object.ptr
end

function _as_anari_object(object::ANARIObjectHandle)
    return object.ptr
end

function _check_object_dtype(dtype::LibANARI.ANARIDataType)
    return dtype in (
        LibANARI.ANARI_DEVICE,
        LibANARI.ANARI_OBJECT,
        LibANARI.ANARI_CAMERA,
        LibANARI.ANARI_FRAME,
        LibANARI.ANARI_RENDERER,
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
    elseif _check_object_dtype(dtype)
        value isa ANARIHandle || throw(ArgumentError("value must be an ANARIHandle for object dtypes"))
        return Ref{LibANARI.ANARIObject}(_as_anari_object(value))
    end

    throw(ArgumentError("unsupported ANARIDataType in setparam!: $dtype"))
end

function setparam!(device::Device, object::Union{Device, ANARIObjectHandle}, name::AbstractString, dtype::LibANARI.ANARIDataType, value)
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