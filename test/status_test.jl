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
