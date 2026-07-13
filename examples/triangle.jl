#!/usr/bin/env julia
# Minimal triangle render example, mirroring cpp_examples/triangle.cpp.
# Uses the generated LibANARI bindings directly (no higher-level wrappers).
#
# Run:
#   julia --project examples/triangle.jl
#
# The helide backend is provided by ANARI_SDK_jll (preloaded on import).

using ANARI_SDK_jll
using ANARI.LibANARI

lib = anariLoadLibrary("helide", C_NULL, C_NULL)
dev = anariNewDevice(lib, "default")

cam = anariNewCamera(dev, "perspective")
anariSetParameter(dev, cam, "position", ANARI_FLOAT32_VEC3, Ref((0.0f0, 0.0f0, 3.0f0)))
anariSetParameter(dev, cam, "direction", ANARI_FLOAT32_VEC3, Ref((0.0f0, 0.0f0, -1.0f0)))
anariCommitParameters(dev, cam)

ren = anariNewRenderer(dev, "default")
anariSetParameter(dev, ren, "background", ANARI_FLOAT32_VEC3, Ref((0.02f0, 0.02f0, 0.03f0)))
anariCommitParameters(dev, ren)

vtx = NTuple{3, Float32}[(-1.0f0, -1.0f0, 0.0f0), (1.0f0, -1.0f0, 0.0f0), (0.0f0, 1.0f0, 0.0f0)]
idx = NTuple{3, UInt32}[(0, 1, 2)]
geo = anariNewGeometry(dev, "triangle")
vtx_array = anariNewArray1D(dev, pointer(vtx), C_NULL, C_NULL, ANARI_FLOAT32_VEC3, 3)
anariSetParameter(dev, geo, "vertex.position", ANARI_ARRAY1D, Ref(vtx_array))
anariRelease(dev, vtx_array)
idx_array = anariNewArray1D(dev, pointer(idx), C_NULL, C_NULL, ANARI_UINT32_VEC3, 1)
anariSetParameter(dev, geo, "primitive.index", ANARI_ARRAY1D, Ref(idx_array))
anariRelease(dev, idx_array)
anariCommitParameters(dev, geo)

mat = anariNewMaterial(dev, "matte")
anariCommitParameters(dev, mat)

surf = anariNewSurface(dev)
anariSetParameter(dev, surf, "geometry", ANARI_GEOMETRY, Ref(geo))
anariRelease(dev, geo)
anariSetParameter(dev, surf, "material", ANARI_MATERIAL, Ref(mat))
anariRelease(dev, mat)
anariCommitParameters(dev, surf)

grp = anariNewGroup(dev)
surface_array = anariNewArray1D(dev, pointer(ANARISurface[surf]), C_NULL, C_NULL, ANARI_SURFACE, 1)
anariSetParameter(dev, grp, "surface", ANARI_ARRAY1D, Ref(surface_array))
anariRelease(dev, surface_array)
anariRelease(dev, surf)
anariCommitParameters(dev, grp)

inst = anariNewInstance(dev, "transform")
anariSetParameter(dev, inst, "group", ANARI_GROUP, Ref(grp))
anariRelease(dev, grp)
anariCommitParameters(dev, inst)

world = anariNewWorld(dev)
instance_array = anariNewArray1D(dev, pointer(ANARIInstance[inst]), C_NULL, C_NULL, ANARI_INSTANCE, 1)
anariSetParameter(dev, world, "instance", ANARI_ARRAY1D, Ref(instance_array))
anariRelease(dev, instance_array)
anariRelease(dev, inst)
anariCommitParameters(dev, world)

size = (UInt32(800), UInt32(600))
frame = anariNewFrame(dev)
anariSetParameter(dev, frame, "size", ANARI_UINT32_VEC2, Ref(size))
anariSetParameter(dev, frame, "channel.color", ANARI_DATA_TYPE, Ref(ANARI_UFIXED8_RGBA_SRGB))
anariSetParameter(dev, frame, "camera", ANARI_CAMERA, Ref(cam))
anariRelease(dev, cam)
anariSetParameter(dev, frame, "renderer", ANARI_RENDERER, Ref(ren))
anariRelease(dev, ren)
anariSetParameter(dev, frame, "world", ANARI_WORLD, Ref(world))
anariRelease(dev, world)
anariCommitParameters(dev, frame)

anariRenderFrame(dev, frame)
while anariFrameReady(dev, frame, ANARI_WAIT) == 0
end

width = Ref{UInt32}(0)
height = Ref{UInt32}(0)
pixel_type = Ref{ANARIDataType}(ANARI_UNKNOWN)
fb = anariMapFrame(dev, frame, "channel.color", width, height, pixel_type)
w = Int(width[])
h = Int(height[])
px = unsafe_wrap(Vector{UInt32}, Ptr{UInt32}(fb), w * h; own = false)

for i in (1, (h ÷ 2) * w + w ÷ 2 + 1)
    p = px[i]
    println("pixel[$i]: $(p & 0xFF) $((p >> 8) & 0xFF) $((p >> 16) & 0xFF)")
end

anariUnmapFrame(dev, frame, "channel.color")
anariRelease(dev, frame)
anariRelease(dev, dev)
anariUnloadLibrary(lib)
