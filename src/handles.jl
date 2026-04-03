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
       Sampler,
       SpatialField,
       Volume,
       Array1D,
       Array2D,
       Array3D,
       release!

abstract type ANARIHandle end

_isnull(ptr::Ptr) = ptr == C_NULL

function _require_nonnull(ptr::Ptr, what::AbstractString)
    _isnull(ptr) && throw(ErrorException("$what returned a null handle"))
    return ptr
end

function _attach_release_finalizer!(obj::ANARIHandle)
    finalizer(obj) do handle
        try
            release!(handle)
        catch
            nothing
        end
    end
    return obj
end

macro define_object_handle(handle_name, ptr_type, create_what)
    return quote
        mutable struct $(esc(handle_name)) <: ANARIObjectHandle
            ptr::$(esc(ptr_type))
            device::Device

            function $(esc(handle_name))(ptr::$(esc(ptr_type)), device::Device)
                _require_nonnull(ptr, $create_what)
                obj = new(ptr, device)
                return _attach_release_finalizer!(obj)
            end
        end
    end
end

macro define_device_handle_constructor(handle_name, create_fn)
    return quote
        function $(esc(handle_name))(device::Device)
            _require_live_device(device)
            ptr = $(esc(create_fn))(device.ptr)
            return $(esc(handle_name))(ptr, device)
        end
    end
end

macro define_subtyped_device_handle_constructor(handle_name, create_fn)
    return quote
        function $(esc(handle_name))(device::Device, subtype::AbstractString)
            _require_live_device(device)
            ptr = $(esc(create_fn))(device.ptr, subtype)
            return $(esc(handle_name))(ptr, device)
        end
    end
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
        return _attach_release_finalizer!(obj)
    end
end

function _require_live_library(library::Library)
    _isnull(library.ptr) && throw(ArgumentError("library handle has already been released"))
    return library
end

mutable struct Device <: ANARIHandle
    ptr::LibANARI.ANARIDevice
    library::Library

    function Device(ptr::LibANARI.ANARIDevice, library::Library)
        _require_nonnull(ptr, "anariNewDevice")
        obj = new(ptr, library)
        return _attach_release_finalizer!(obj)
    end
end

function _require_live_device(device::Device)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    return device
end

abstract type ANARIObjectHandle <: ANARIHandle end

@define_object_handle World LibANARI.ANARIWorld "anariNewWorld"
@define_object_handle Frame LibANARI.ANARIFrame "anariNewFrame"
@define_object_handle Camera LibANARI.ANARICamera "anariNewCamera"
@define_object_handle Renderer LibANARI.ANARIRenderer "anariNewRenderer"
@define_object_handle Geometry LibANARI.ANARIGeometry "anariNewGeometry"
@define_object_handle Material LibANARI.ANARIMaterial "anariNewMaterial"
@define_object_handle Surface LibANARI.ANARISurface "anariNewSurface"
@define_object_handle Group LibANARI.ANARIGroup "anariNewGroup"
@define_object_handle Instance LibANARI.ANARIInstance "anariNewInstance"
@define_object_handle Light LibANARI.ANARILight "anariNewLight"
@define_object_handle Sampler LibANARI.ANARISampler "anariNewSampler"
@define_object_handle SpatialField LibANARI.ANARISpatialField "anariNewSpatialField"
@define_object_handle Volume LibANARI.ANARIVolume "anariNewVolume"

"""
    Array1D

Wrapper for an `ANARIArray1D` handle. Unlike a Julia `Array{T}`, this type is not parameterized: ANARI fixes element
datatype and length at runtime. The wrapper stores `length::UInt64` and `eltype::Type`, where `eltype` is the Julia
type used to view mapped data (see `map_array`) or `Any` when unknown (for example arrays built from a raw pointer).
`new_array1d` sets `eltype` from the source vector’s element type, or `LibANARI.ANARIObject` for vectors of object
handles. `Base.eltype(::Array1D)` returns the `eltype` field.
"""
mutable struct Array1D <: ANARIObjectHandle
    ptr::LibANARI.ANARIArray1D
    device::Device
    length::UInt64
    eltype::Type

    function Array1D(
        ptr::LibANARI.ANARIArray1D,
        device::Device,
        length::Integer = 0,
        eltype::Type = Any,
    )
        _require_nonnull(ptr, "anariNewArray1D")
        length < 0 && throw(ArgumentError("array length must be non-negative"))
        obj = new(ptr, device, UInt64(length), eltype)
        return _attach_release_finalizer!(obj)
    end
end

"""
    Array2D

Wrapper for an `ANARIArray2D` handle. Element datatype and extents are fixed at runtime; the wrapper stores
`dims::Tuple{UInt64,UInt64}` as `(numElements1, numElements2)` in ANARI order (the first dimension varies fastest
in linear memory, matching Julia’s column-major `Matrix` layout). `new_array2d` sets `eltype` from the matrix element
type, or `LibANARI.ANARIObject` for matrices of object handles. `Base.size(::Array2D)` returns `dims` as `Int` tuples.
`Base.eltype(::Array2D)` returns the `eltype` field.
"""
mutable struct Array2D <: ANARIObjectHandle
    ptr::LibANARI.ANARIArray2D
    device::Device
    dims::NTuple{2,UInt64}
    eltype::Type

    function Array2D(
        ptr::LibANARI.ANARIArray2D,
        device::Device,
        dims::Tuple{Integer,Integer} = (0, 0),
        eltype::Type = Any,
    )
        _require_nonnull(ptr, "anariNewArray2D")
        (dims[1] < 0 || dims[2] < 0) && throw(ArgumentError("array dimensions must be non-negative"))
        obj = new(ptr, device, (UInt64(dims[1]), UInt64(dims[2])), eltype)
        return _attach_release_finalizer!(obj)
    end
end

Base.size(a::Array2D) = (Int(a.dims[1]), Int(a.dims[2]))

"""
    Array3D

Wrapper for an `ANARIArray3D` handle. Same conventions as `Array2D`, with `dims::Tuple{UInt64,UInt64,UInt64}` for
`(numElements1, numElements2, numElements3)`; linear order matches Julia’s column-major `Array{T,3}` layout.
"""
mutable struct Array3D <: ANARIObjectHandle
    ptr::LibANARI.ANARIArray3D
    device::Device
    dims::NTuple{3,UInt64}
    eltype::Type

    function Array3D(
        ptr::LibANARI.ANARIArray3D,
        device::Device,
        dims::Tuple{Integer,Integer,Integer} = (0, 0, 0),
        eltype::Type = Any,
    )
        _require_nonnull(ptr, "anariNewArray3D")
        if dims[1] < 0 || dims[2] < 0 || dims[3] < 0
            throw(ArgumentError("array dimensions must be non-negative"))
        end
        obj = new(
            ptr,
            device,
            (UInt64(dims[1]), UInt64(dims[2]), UInt64(dims[3])),
            eltype,
        )
        return _attach_release_finalizer!(obj)
    end
end

Base.size(a::Array3D) = (Int(a.dims[1]), Int(a.dims[2]), Int(a.dims[3]))

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
    _require_live_library(library)
    ptr = LibANARI.anariNewDevice(library.ptr, subtype)
    return Device(ptr, library)
end

@define_device_handle_constructor World LibANARI.anariNewWorld
@define_device_handle_constructor Frame LibANARI.anariNewFrame
@define_subtyped_device_handle_constructor Camera LibANARI.anariNewCamera
@define_subtyped_device_handle_constructor Renderer LibANARI.anariNewRenderer
@define_subtyped_device_handle_constructor Geometry LibANARI.anariNewGeometry
@define_subtyped_device_handle_constructor Material LibANARI.anariNewMaterial
@define_device_handle_constructor Surface LibANARI.anariNewSurface
@define_device_handle_constructor Group LibANARI.anariNewGroup
@define_subtyped_device_handle_constructor Instance LibANARI.anariNewInstance
@define_subtyped_device_handle_constructor Light LibANARI.anariNewLight
@define_subtyped_device_handle_constructor Sampler LibANARI.anariNewSampler
@define_subtyped_device_handle_constructor SpatialField LibANARI.anariNewSpatialField
@define_subtyped_device_handle_constructor Volume LibANARI.anariNewVolume

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