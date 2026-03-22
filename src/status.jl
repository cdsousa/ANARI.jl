using Logging

function _severity_name(severity::Integer)
    if severity == LibANARI.ANARI_SEVERITY_FATAL_ERROR
        return "fatal"
    elseif severity == LibANARI.ANARI_SEVERITY_ERROR
        return "error"
    elseif severity == LibANARI.ANARI_SEVERITY_WARNING
        return "warning"
    elseif severity == LibANARI.ANARI_SEVERITY_PERFORMANCE_WARNING
        return "performance_warning"
    elseif severity == LibANARI.ANARI_SEVERITY_INFO
        return "info"
    elseif severity == LibANARI.ANARI_SEVERITY_DEBUG
        return "debug"
    end

    return "unknown"
end

function _log_status_event(
    severity::Integer,
    code::Integer,
    source_type::Integer,
    message::AbstractString,
)
    log_message =
        "ANARI status [severity=$(_severity_name(severity)) ($(Int(severity))), code=$(Int(code)), sourceType=$(Int(source_type))]: $message"

    if severity == LibANARI.ANARI_SEVERITY_FATAL_ERROR || severity == LibANARI.ANARI_SEVERITY_ERROR
        @error log_message
    elseif severity == LibANARI.ANARI_SEVERITY_WARNING || severity == LibANARI.ANARI_SEVERITY_PERFORMANCE_WARNING
        @warn log_message
    elseif severity == LibANARI.ANARI_SEVERITY_INFO
        @info log_message
    else
        @debug log_message
    end

    return nothing
end

function _status_callback(
    user_ptr::Ptr{Cvoid},
    device::LibANARI.ANARIDevice,
    source::LibANARI.ANARIObject,
    source_type::LibANARI.ANARIDataType,
    severity::LibANARI.ANARIStatusSeverity,
    code::LibANARI.ANARIStatusCode,
    message::Cstring,
)::Cvoid
    message_text = message == C_NULL ? "<null>" : unsafe_string(message)
    _log_status_event(severity, code, source_type, message_text)
    return
end

function _invoke_user_status_callback(
    callback::Function,
    severity::Integer,
    code::Integer,
    source_type::Integer,
    message::AbstractString,
)
    if applicable(callback, severity, code, source_type, message)
        callback(severity, code, source_type, message)
    elseif applicable(callback, message)
        callback(message)
    else
        throw(ArgumentError("status callback must accept either (message) or (severity, code, source_type, message)"))
    end

    return nothing
end

function _status_callback_user(
    user_ptr::Ptr{Cvoid},
    device::LibANARI.ANARIDevice,
    source::LibANARI.ANARIObject,
    source_type::LibANARI.ANARIDataType,
    severity::LibANARI.ANARIStatusSeverity,
    code::LibANARI.ANARIStatusCode,
    message::Cstring,
)::Cvoid
    message_text = message == C_NULL ? "<null>" : unsafe_string(message)

    if user_ptr == C_NULL
        _log_status_event(severity, code, source_type, message_text)
        return
    end

    try
        callback_ref = unsafe_pointer_to_objref(user_ptr)
        callback = callback_ref isa Base.RefValue ? callback_ref[] : callback_ref
        callback isa Function || throw(ArgumentError("status callback user data is not a Function"))
        _invoke_user_status_callback(callback, severity, code, source_type, message_text)
    catch err
        @error "user status callback threw" exception=(err, catch_backtrace())
        _log_status_event(severity, code, source_type, message_text)
    end

    return
end

const _STATUS_CALLBACK_PTR = @cfunction(
    _status_callback,
    Cvoid,
    (
        Ptr{Cvoid},
        LibANARI.ANARIDevice,
        LibANARI.ANARIObject,
        LibANARI.ANARIDataType,
        LibANARI.ANARIStatusSeverity,
        LibANARI.ANARIStatusCode,
        Cstring,
    ),
)

const _STATUS_CALLBACK_USER_PTR = @cfunction(
    _status_callback_user,
    Cvoid,
    (
        Ptr{Cvoid},
        LibANARI.ANARIDevice,
        LibANARI.ANARIObject,
        LibANARI.ANARIDataType,
        LibANARI.ANARIStatusSeverity,
        LibANARI.ANARIStatusCode,
        Cstring,
    ),
)
