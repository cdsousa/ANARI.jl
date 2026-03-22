@testset "Handle wrappers unit tests" begin
    @test_throws ErrorException ANARI.Library(ANARI.LibANARI.ANARILibrary(C_NULL))

    lib = ANARI.Library("helide")
    @test lib.ptr != C_NULL

    dev = ANARI.Device(lib, "default")
    @test dev.ptr != C_NULL

    ANARI.release!(dev)
    @test dev.ptr == C_NULL

    # Release operations should be safe to call more than once.
    ANARI.release!(dev)
    @test dev.ptr == C_NULL

    ANARI.release!(lib)
    @test lib.ptr == C_NULL

    ANARI.release!(lib)
    @test lib.ptr == C_NULL

    @test_throws ArgumentError ANARI.Device(lib, "default")
end