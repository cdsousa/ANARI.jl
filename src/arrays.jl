export new_array1d, map_array, unmap_array

Base.eltype(a::Array1D) = a.eltype

"""
    new_array1d(device, data::AbstractVector) -> Array1D

Allocate an ANARI 1D array on `device`, copy `data` into it, and return an `Array1D` whose `length` and `eltype`
fields describe the copy (object-handle vectors use `eltype == LibANARI.ANARIObject`).
"""
function new_array1d(device::Device, data::AbstractVector{T}) where {T<:ANARIObjectHandle}
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    values = LibANARI.ANARIObject[]
    sizehint!(values, length(data))
    for object in data
        _isnull(object.ptr) && throw(ArgumentError("array element handle has already been released"))
        push!(values, _as_anari_object(object))
    end

    ptr = LibANARI.anariNewArray1D(
        device.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        anari_type(T),
        UInt64(length(values)),
    )
    array = Array1D(ptr, device, length(values), LibANARI.ANARIObject)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{LibANARI.ANARIObject}(mapped), pointer(values), length(values))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

function new_array1d(device::Device, data::AbstractVector{T}) where {T}
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))

    values = collect(data)
    dtype = anari_type(T)

    ptr = LibANARI.anariNewArray1D(
        device.ptr,
        C_NULL,
        C_NULL,
        C_NULL,
        dtype,
        UInt64(length(values)),
    )
    array = Array1D(ptr, device, length(values), T)

    mapped = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(mapped) && throw(ErrorException("anariMapArray returned a null data pointer"))

    try
        unsafe_copyto!(Ptr{T}(mapped), pointer(values), length(values))
    finally
        LibANARI.anariUnmapArray(device.ptr, array.ptr)
    end

    return array
end

"""
    map_array(device, array::Array1D)

Map the array for CPU access. If `array.eltype === Any`, returns `Ptr{Cvoid}`; otherwise returns
`unsafe_wrap(Vector{array.eltype}, ...)` using the stored element count.
"""
function map_array(device::Device, array::Array1D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    data_ptr = LibANARI.anariMapArray(device.ptr, array.ptr)
    _isnull(data_ptr) && throw(ErrorException("anariMapArray returned a null data pointer"))
    T = array.eltype
    if T === Any
        return data_ptr
    end
    return unsafe_wrap(Vector{T}, Ptr{T}(data_ptr), Int(array.length))
end

"""
    unmap_array(device, array::Array1D)

Unmap memory previously mapped with `map_array`.
"""
function unmap_array(device::Device, array::Array1D)
    _isnull(device.ptr) && throw(ArgumentError("device handle has already been released"))
    _isnull(array.ptr) && throw(ArgumentError("array handle has already been released"))

    LibANARI.anariUnmapArray(device.ptr, array.ptr)
    return nothing
end
