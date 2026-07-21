"""
    setparam!(device, object, name, dataType, value)
    setparam!(object, name, dataType, value)

Call `anariSetParameter` with `value` wrapped in a `Ref` and pinned via
`GC.@preserve` for the duration of the call.

Accepts raw handles, `Device`/`Object` wrappers, and typed object values for
object-typed parameters.
"""
function setparam!(device, object, name::AbstractString, dataType, value)
    value = _parameter_value(value)
    value_ref = value isa Base.RefValue ? value : Ref(value)
    GC.@preserve value value_ref begin
        anariSetParameter(
            _device_handle(device),
            _object_handle(object),
            name,
            dataType,
            value_ref,
        )
    end
    return nothing
end

function setparam!(object::Object, name::AbstractString, dataType, value)
    return setparam!(object.device, object, name, dataType, value)
end

"""
    commit!(device, object)
    commit!(object)

Call `anariCommitParameters`.
"""
function commit!(device, object)
    anariCommitParameters(_device_handle(device), _object_handle(object))
    return nothing
end

commit!(object::Object) = commit!(object.device, object)

"""
    release!(object)
    release!(device)
    release!(library)

Call `anariRelease` or `anariUnloadLibrary` as appropriate.
"""
function release!(object::Object)
    anariRelease(object.device.handle, object.handle)
    return nothing
end

function release!(device::Device)
    anariRelease(device.handle, device.handle)
    return nothing
end

function release!(library::Library)
    anariUnloadLibrary(library.handle)
    return nothing
end
