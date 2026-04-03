export anari_type

"""
    anari_type(::Type{T}) -> ANARIDataType

Return the ANARI data type constant corresponding to Julia type `T`.

Downstream packages can extend this function to add support for additional types.
"""
function anari_type end

# Scalar types
anari_type(::Type{Bool})    = LibANARI.ANARI_BOOL
anari_type(::Type{Int32})   = LibANARI.ANARI_INT32
anari_type(::Type{UInt32})  = LibANARI.ANARI_UINT32
anari_type(::Type{Float32}) = LibANARI.ANARI_FLOAT32
anari_type(::Type{Float64}) = LibANARI.ANARI_FLOAT64

# Vector types (as NTuples)
anari_type(::Type{NTuple{2, UInt32}})  = LibANARI.ANARI_UINT32_VEC2
anari_type(::Type{NTuple{3, UInt32}})  = LibANARI.ANARI_UINT32_VEC3
anari_type(::Type{NTuple{2, Float32}}) = LibANARI.ANARI_FLOAT32_VEC2
anari_type(::Type{NTuple{3, Float32}}) = LibANARI.ANARI_FLOAT32_VEC3
anari_type(::Type{NTuple{4, Float32}}) = LibANARI.ANARI_FLOAT32_VEC4

# Handle types
anari_type(::Type{Device})   = LibANARI.ANARI_DEVICE
anari_type(::Type{World})    = LibANARI.ANARI_WORLD
anari_type(::Type{Frame})    = LibANARI.ANARI_FRAME
anari_type(::Type{Camera})   = LibANARI.ANARI_CAMERA
anari_type(::Type{Renderer}) = LibANARI.ANARI_RENDERER
anari_type(::Type{Geometry}) = LibANARI.ANARI_GEOMETRY
anari_type(::Type{Material}) = LibANARI.ANARI_MATERIAL
anari_type(::Type{Surface})  = LibANARI.ANARI_SURFACE
anari_type(::Type{Group})    = LibANARI.ANARI_GROUP
anari_type(::Type{Instance}) = LibANARI.ANARI_INSTANCE
anari_type(::Type{Light})    = LibANARI.ANARI_LIGHT
anari_type(::Type{Sampler})       = LibANARI.ANARI_SAMPLER
anari_type(::Type{SpatialField})  = LibANARI.ANARI_SPATIAL_FIELD
anari_type(::Type{Volume})        = LibANARI.ANARI_VOLUME
anari_type(::Type{Array1D}) = LibANARI.ANARI_ARRAY1D
anari_type(::Type{Array2D}) = LibANARI.ANARI_ARRAY2D
anari_type(::Type{Array3D}) = LibANARI.ANARI_ARRAY3D

"""
    setparam!(device, object, name, value)

Set parameter `name` on `object` using the device, inferring the ANARI data type
from `typeof(value)` via `anari_type`. Provides a concise alternative to the
explicit `setparam!(device, object, name, dtype, value)` form.
"""
function setparam!(
    device::Device,
    object::Union{Device, ANARIObjectHandle},
    name::AbstractString,
    value,
)
    return setparam!(device, object, name, anari_type(typeof(value)), value)
end
