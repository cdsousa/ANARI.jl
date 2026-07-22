"""
    Library(handle)

Wrapper around an `ANARILibrary` handle. Registers a finalizer that calls
`release!`; see [`release!`](@ref) for manual cleanup.
"""
mutable struct Library
    handle::ANARILibrary

    function Library(handle::ANARILibrary)
        handle == C_NULL && throw(ArgumentError("ANARI library handle is null"))
        lib = new(handle)
        finalizer(release!, lib)
        return lib
    end
end

"""
    Device(library, handle)

Wrapper around an `ANARIDevice` handle. Keeps the owning `Library` alive.
Registers a finalizer that calls `release!`; see [`release!`](@ref) for manual
cleanup.
"""
mutable struct Device
    library::Library
    handle::ANARIDevice

    function Device(library::Library, handle::ANARIDevice)
        handle == C_NULL && throw(ArgumentError("ANARI device handle is null"))
        dev = new(library, handle)
        finalizer(release!, dev)
        return dev
    end
end

"""
    ObjectKind

Tag type for parametric ANARI object wrappers. Concrete subtypes such as
`CameraKind` are generated in `generated/wrappers.jl`.
"""
abstract type ObjectKind end

"""
    Object{K}(device, handle)

Parametric wrapper around an ANARI object handle. Keeps the owning `Device`
(and `Library`) alive. Registers a finalizer that calls `release!`; see
[`release!`](@ref) for manual cleanup.

Typed aliases such as `Camera = Object{CameraKind}` are generated in
`generated/wrappers.jl`.
"""
mutable struct Object{K <: ObjectKind}
    device::Device
    handle::ANARIHandle

    function Object(device::Device, handle::ANARIHandle, ::Type{K}) where {K <: ObjectKind}
        handle == C_NULL && throw(ArgumentError("ANARI object handle is null"))
        obj = new{K}(device, handle)
        finalizer(release!, obj)
        return obj
    end
end

"""
    Object(device, handle)

Untyped object wrapper equivalent to `Object{UntypedObjectKind}`.
"""
struct UntypedObjectKind <: ObjectKind end

Object(device::Device, handle::ANARIHandle) = Object(device, handle, UntypedObjectKind)

_object_handle(object::Object) = object.handle
_object_handle(object) = object

_device_handle(device::Device) = device.handle
_device_handle(device::ANARIDevice) = device

_parameter_value(value::Object) = value.handle
_parameter_value(value) = value
