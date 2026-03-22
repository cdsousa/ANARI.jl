using Logging

@testset "Status callback logging bridge" begin
    L = ANARI.LibANARI

    @test_logs (:error, r"severity=fatal") ANARI._log_status_event(
        L.ANARI_SEVERITY_FATAL_ERROR,
        L.ANARI_STATUS_UNKNOWN_ERROR,
        L.ANARI_UNKNOWN,
        "fatal message",
    )

    @test_logs (:warn, r"severity=warning") ANARI._log_status_event(
        L.ANARI_SEVERITY_WARNING,
        L.ANARI_STATUS_INVALID_OPERATION,
        L.ANARI_WORLD,
        "warn message",
    )

    @test_logs (:info, r"severity=info") ANARI._log_status_event(
        L.ANARI_SEVERITY_INFO,
        L.ANARI_STATUS_NO_ERROR,
        L.ANARI_DEVICE,
        "info message",
    )
end

@testset "Library constructor with status logging" begin
    lib = ANARI.Library("helide"; status_logging=true)
    @test lib.ptr != C_NULL
    @test lib.status_callback != C_NULL

    ANARI.release!(lib)
    @test lib.ptr == C_NULL
    @test lib.status_callback == C_NULL
end

@testset "Library constructor with user status callback" begin
    L = ANARI.LibANARI

    events = Tuple{Int, Int, Int, String}[]
    callback = (severity, code, source_type, message) -> push!(
        events,
        (Int(severity), Int(code), Int(source_type), String(message)),
    )

    lib = ANARI.Library("helide", callback)
    @test lib.ptr != C_NULL
    @test lib.status_callback != C_NULL
    @test lib.status_user_data != C_NULL
    @test lib.status_user_data_ref !== nothing

    callback_ref = unsafe_pointer_to_objref(lib.status_user_data)
    callback_fn = callback_ref isa Base.RefValue ? callback_ref[] : callback_ref
    ANARI._invoke_user_status_callback(
        callback_fn,
        L.ANARI_SEVERITY_INFO,
        L.ANARI_STATUS_NO_ERROR,
        L.ANARI_DEVICE,
        "custom message",
    )

    @test length(events) == 1
    @test events[1] == (
        Int(L.ANARI_SEVERITY_INFO),
        Int(L.ANARI_STATUS_NO_ERROR),
        Int(L.ANARI_DEVICE),
        "custom message",
    )

    ANARI.release!(lib)
    @test lib.ptr == C_NULL
    @test lib.status_callback == C_NULL
    @test lib.status_user_data == C_NULL
    @test lib.status_user_data_ref === nothing
end
