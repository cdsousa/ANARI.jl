using Test
using ANARI

@testset "LibANARI smoke test" begin
    # Basic shape checks so we know generated bindings are loaded.
    @test isdefined(ANARI, :LibANARI)
    @test isdefined(ANARI.LibANARI, :anariLoadLibrary)

    # Try loading the default `helide` library through the C binding.
    lib = ANARI.LibANARI.anariLoadLibrary("helide", C_NULL, C_NULL)
    @test lib isa Ptr{Cvoid}
    @test lib != C_NULL

    if lib != C_NULL
        ANARI.LibANARI.anariUnloadLibrary(lib)
    end
end

@testset "LibANARI minimal render smoke test" begin
    L = ANARI.LibANARI

    lib = C_NULL
    device = C_NULL
    renderer = C_NULL
    camera = C_NULL
    world = C_NULL
    frame = C_NULL

    try
        lib = L.anariLoadLibrary("helide", C_NULL, C_NULL)
        @test lib != C_NULL

        device = L.anariNewDevice(lib, "default")
        @test device != C_NULL

        renderer = L.anariNewRenderer(device, "default")
        @test renderer != C_NULL

        camera = L.anariNewCamera(device, "default")
        @test camera != C_NULL

        world = L.anariNewWorld(device)
        @test world != C_NULL

        frame = L.anariNewFrame(device)
        @test frame != C_NULL

        size = Ref{NTuple{2, UInt32}}((64, 64))
        renderer_ref = Ref(renderer)
        camera_ref = Ref(camera)
        world_ref = Ref(world)

        L.anariSetParameter(device, frame, "size", L.ANARI_UINT32_VEC2, size)
        L.anariSetParameter(device, frame, "renderer", L.ANARI_RENDERER, renderer_ref)
        L.anariSetParameter(device, frame, "camera", L.ANARI_CAMERA, camera_ref)
        L.anariSetParameter(device, frame, "world", L.ANARI_WORLD, world_ref)

        L.anariCommitParameters(device, renderer)
        L.anariCommitParameters(device, camera)
        L.anariCommitParameters(device, world)
        L.anariCommitParameters(device, frame)

        L.anariRenderFrame(device, frame)
        ready = L.anariFrameReady(device, frame, L.ANARI_WAIT)
        @test ready != 0
    finally
        frame != C_NULL && L.anariRelease(device, frame)
        world != C_NULL && L.anariRelease(device, world)
        camera != C_NULL && L.anariRelease(device, camera)
        renderer != C_NULL && L.anariRelease(device, renderer)
        device != C_NULL && L.anariRelease(device, device)
        lib != C_NULL && L.anariUnloadLibrary(lib)
    end
end
