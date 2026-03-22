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
