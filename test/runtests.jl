using Test
using ANARI
using ANARI.LibANARI

@testset "generated core API" begin
    @test isdefined(LibANARI, :ANARIDataType)
    @test isdefined(LibANARI, :ANARI_FLOAT32_VEC3)
    @test Integer(LibANARI.ANARI_FLOAT32_VEC3) == 1070
    @test isdefined(LibANARI, :anariLoadLibrary)
    @test isdefined(LibANARI, :anariNewDevice)
    @test LibANARI.ANARIDevice === LibANARI.ANARIHandle
end

@testset "datatype metadata" begin
    @test LibANARI.julia_type(LibANARI.ANARI_FLOAT32_VEC3) == NTuple{3, Float32}
    @test LibANARI.c_type(LibANARI.ANARI_STRING) == Cstring
    @test LibANARI.datatype_components(LibANARI.ANARI_FLOAT32_MAT4) == 16
    @test !LibANARI.is_normalized(LibANARI.ANARI_FLOAT32_VEC3)
    @test LibANARI.is_normalized(LibANARI.ANARI_UFIXED8_RGBA_SRGB)
end

@testset "object metadata" begin
    subtypes = LibANARI.object_subtypes(LibANARI.ANARI_MATERIAL)
    @test "matte" in subtypes
    @test "physicallyBased" in subtypes

    specs = LibANARI.parameter_specs(LibANARI.ANARI_MATERIAL, "matte")
    color = LibANARI.parameter_spec(LibANARI.ANARI_MATERIAL, "matte", "color")
    @test color !== nothing
    @test LibANARI.ANARI_FLOAT32_VEC3 in color.types
    @test color.default == (0.8f0, 0.8f0, 0.8f0)

    frame_specs = LibANARI.parameter_specs(LibANARI.ANARI_FRAME)
    @test any(spec -> spec.name == "world" && LibANARI.is_required(spec), frame_specs)
    @test haskey(LibANARI.ATTRIBUTES, "color")
end

@testset "LibANARI loads" begin
    @test LibANARI.libanari != C_NULL
end

@testset "handle wrappers" begin
    using ANARI: Library, Device, Object, Camera, Geometry, Material, Surface
    using ANARI: Group, Instance, World, Renderer, Frame, Array1D
    using ANARI: setparam!, commit!, release!, object_data_type

    @test_throws ArgumentError Library(C_NULL)

    lib_handle = anariLoadLibrary("helide", C_NULL, C_NULL)
    lib = Library(lib_handle)
    @test lib.handle == lib_handle

    dev = Device(lib, anariNewDevice(lib.handle, "default"))
    @test dev.library === lib

    @test_throws ArgumentError Object(dev, C_NULL)

    cam = Camera(dev, "perspective")
    @test cam isa Camera
    @test object_data_type(cam) == ANARI_CAMERA
    @test cam.device === dev
    setparam!(cam, "position", ANARI_FLOAT32_VEC3, (0.0f0, 0.0f0, 1.0f0))
    commit!(cam)

    geo = Geometry(dev, "triangle")
    @test geo isa Geometry
    @test object_data_type(geo) == ANARI_GEOMETRY

    untyped = Object(dev, anariNewMaterial(dev.handle, "matte"))
    @test untyped isa Object{UntypedObjectKind}
    @test object_data_type(untyped) == ANARI_OBJECT
    release!(untyped)

    release!(cam)
    release!(geo)
    release!(dev)
    release!(lib)
end
