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
