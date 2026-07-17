"""
    set_parameter_safe(device, object, name, dataType, value)

Call `anariSetParameter` with `value` wrapped in a `Ref` and pinned via
`GC.@preserve` for the duration of the call.
"""
function set_parameter_safe(device, object, name::AbstractString, dataType, value)
    value_ref = value isa Base.RefValue ? value : Ref(value)
    GC.@preserve value value_ref begin
        anariSetParameter(device, object, name, dataType, value_ref)
    end
    return nothing
end
