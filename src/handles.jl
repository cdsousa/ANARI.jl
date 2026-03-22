export ANARIHandle, Library, Device, release!

abstract type ANARIHandle end

_isnull(ptr::Ptr) = ptr == C_NULL

function _require_nonnull(ptr::Ptr, what::AbstractString)
    _isnull(ptr) && throw(ErrorException("$what returned a null handle"))
    return ptr
end

mutable struct Library <: ANARIHandle
    ptr::LibANARI.ANARILibrary

    function Library(ptr::LibANARI.ANARILibrary)
        _require_nonnull(ptr, "anariLoadLibrary")
        obj = new(ptr)
        finalizer(obj) do lib
            try
                release!(lib)
            catch
                nothing
            end
        end
        return obj
    end
end

mutable struct Device <: ANARIHandle
    ptr::LibANARI.ANARIDevice
    library::Library

    function Device(ptr::LibANARI.ANARIDevice, library::Library)
        _require_nonnull(ptr, "anariNewDevice")
        obj = new(ptr, library)
        finalizer(obj) do dev
            try
                release!(dev)
            catch
                nothing
            end
        end
        return obj
    end
end

function Library(name::AbstractString)
    ptr = LibANARI.anariLoadLibrary(name, C_NULL, C_NULL)
    return Library(ptr)
end

function Device(library::Library, subtype::AbstractString)
    _isnull(library.ptr) && throw(ArgumentError("library handle has already been released"))
    ptr = LibANARI.anariNewDevice(library.ptr, subtype)
    return Device(ptr, library)
end

function release!(library::Library)
    _isnull(library.ptr) && return nothing
    LibANARI.anariUnloadLibrary(library.ptr)
    library.ptr = LibANARI.ANARILibrary(C_NULL)
    return nothing
end

function release!(device::Device)
    _isnull(device.ptr) && return nothing
    LibANARI.anariRelease(device.ptr, device.ptr)
    device.ptr = LibANARI.ANARIDevice(C_NULL)
    return nothing
end