export ANARIHandle,
       Library,
       Device,
       World,
       Frame,
       Camera,
       Renderer,
       Geometry,
       Material,
       Surface,
       Group,
       Instance,
       Light,
       Array1D,
       release!

abstract type ANARIHandle end

_isnull(ptr::Ptr) = ptr == C_NULL

function _require_nonnull(ptr::Ptr, what::AbstractString)
    _isnull(ptr) && throw(ErrorException("$what returned a null handle"))
    return ptr
end

mutable struct Library <: ANARIHandle
    ptr::LibANARI.ANARILibrary
    status_callback::LibANARI.ANARIStatusCallback
    status_user_data::Ptr{Cvoid}
    status_user_data_ref::Any

    function Library(
        ptr::LibANARI.ANARILibrary,
        status_callback::LibANARI.ANARIStatusCallback=C_NULL,
        status_user_data::Ptr{Cvoid}=C_NULL,
        status_user_data_ref::Any=nothing,
    )
        _require_nonnull(ptr, "anariLoadLibrary")
        obj = new(ptr, status_callback, status_user_data, status_user_data_ref)
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

mutable struct Geometry <: ANARIObjectHandle
    ptr::LibANARI.ANARIGeometry
    device::Device

    function Geometry(ptr::LibANARI.ANARIGeometry, device::Device)
        _require_nonnull(ptr, "anariNewGeometry")
        obj = new(ptr, device)
        finalizer(obj) do geometry
            try
                release!(geometry)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Material <: ANARIObjectHandle
    ptr::LibANARI.ANARIMaterial
    device::Device

    function Material(ptr::LibANARI.ANARIMaterial, device::Device)
        _require_nonnull(ptr, "anariNewMaterial")
        obj = new(ptr, device)
        finalizer(obj) do material
            try
                release!(material)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Surface <: ANARIObjectHandle
    ptr::LibANARI.ANARISurface
    device::Device

    function Surface(ptr::LibANARI.ANARISurface, device::Device)
        _require_nonnull(ptr, "anariNewSurface")
        obj = new(ptr, device)
        finalizer(obj) do surface
            try
                release!(surface)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Group <: ANARIObjectHandle
    ptr::LibANARI.ANARIGroup
    device::Device

    function Group(ptr::LibANARI.ANARIGroup, device::Device)
        _require_nonnull(ptr, "anariNewGroup")
        obj = new(ptr, device)
        finalizer(obj) do group
            try
                release!(group)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Instance <: ANARIObjectHandle
    ptr::LibANARI.ANARIInstance
    device::Device

    function Instance(ptr::LibANARI.ANARIInstance, device::Device)
        _require_nonnull(ptr, "anariNewInstance")
        obj = new(ptr, device)
        finalizer(obj) do instance
            try
                release!(instance)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Light <: ANARIObjectHandle
    ptr::LibANARI.ANARILight
    device::Device

    function Light(ptr::LibANARI.ANARILight, device::Device)
        _require_nonnull(ptr, "anariNewLight")
        obj = new(ptr, device)
        finalizer(obj) do light
            try
                release!(light)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Array1D{T} <: ANARIObjectHandle
    ptr::LibANARI.ANARIArray1D
    device::Device
    length::UInt64

    function Array1D{T}(ptr::LibANARI.ANARIArray1D, device::Device, length::Integer) where {T}
        _require_nonnull(ptr, "anariNewArray1D")
        length < 0 && throw(ArgumentError("array length must be non-negative"))
        obj = new{T}(ptr, device, UInt64(length))
        finalizer(obj) do array
            try
                release!(array)
            catch
                nothing
            end
        end
        return obj
    end
end

function Array1D(ptr::LibANARI.ANARIArray1D, device::Device, length::Integer=0)
    return Array1D{Any}(ptr, device, length)
end

function Library(name::AbstractString; status_logging::Bool=false)
    callback_ptr = status_logging ? _STATUS_CALLBACK_PTR : C_NULL
    ptr = LibANARI.anariLoadLibrary(name, callback_ptr, C_NULL)
    return Library(ptr, callback_ptr, C_NULL, nothing)
end

function Library(name::AbstractString, status_callback::Function)
    callback_ref = Ref{Any}(status_callback)
    user_data_ptr = Base.pointer_from_objref(callback_ref)
    ptr = LibANARI.anariLoadLibrary(name, _STATUS_CALLBACK_USER_PTR, user_data_ptr)
    return Library(ptr, _STATUS_CALLBACK_USER_PTR, user_data_ptr, callback_ref)
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

function Geometry(device::Device, subtype::AbstractString)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewGeometry(device.ptr, subtype)
    return Geometry(ptr, device)
end

function Material(device::Device, subtype::AbstractString)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewMaterial(device.ptr, subtype)
    return Material(ptr, device)
end

function Surface(device::Device)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewSurface(device.ptr)
    return Surface(ptr, device)
end

function Group(device::Device)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewGroup(device.ptr)
    return Group(ptr, device)
end

function Instance(device::Device, subtype::AbstractString)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewInstance(device.ptr, subtype)
    return Instance(ptr, device)
end

function Light(device::Device, subtype::AbstractString)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    ptr = LibANARI.anariNewLight(device.ptr, subtype)
    return Light(ptr, device)
end

function release!(library::Library)
    _isnull(library.ptr) && return nothing
    LibANARI.anariUnloadLibrary(library.ptr)
    library.ptr = LibANARI.ANARILibrary(C_NULL)
    library.status_callback = LibANARI.ANARIStatusCallback(C_NULL)
    library.status_user_data = C_NULL
    library.status_user_data_ref = nothing
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