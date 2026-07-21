"""
    Library(handle)

Wrapper around an `ANARILibrary` handle.
"""
struct Library
    handle::ANARILibrary

    function Library(handle::ANARILibrary)
        handle == C_NULL && throw(ArgumentError("ANARI library handle is null"))
        return new(handle)
    end
end

"""
    Device(library, handle)

Wrapper around an `ANARIDevice` handle. Keeps the owning `Library` alive.
"""
struct Device
    library::Library
    handle::ANARIDevice

    function Device(library::Library, handle::ANARIDevice)
        handle == C_NULL && throw(ArgumentError("ANARI device handle is null"))
        return new(library, handle)
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
(and `Library`) alive.

Typed aliases such as `Camera = Object{CameraKind}` are generated in
`generated/wrappers.jl`.
"""
struct Object{K <: ObjectKind}
    device::Device
    handle::ANARIHandle

    function Object(device::Device, handle::ANARIHandle, ::Type{K}) where {K <: ObjectKind}
        handle == C_NULL && throw(ArgumentError("ANARI object handle is null"))
        return new{K}(device, handle)
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
