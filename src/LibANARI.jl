module LibANARI

using ANARI_SDK_jll
export ANARI_SDK_jll

using CEnum: CEnum, @cenum

const ANARIDataType = Cint

const ANARILogLevel = Cint

const ANARIWaitMask = Cuint

const ANARIStatusCode = Cint

const ANARIStatusSeverity = Cint

const ANARILibrary = Ptr{Cvoid}

const ANARIObject = Ptr{Cvoid}

const ANARIDevice = Ptr{Cvoid}

const ANARICamera = Ptr{Cvoid}

const ANARIArray = Ptr{Cvoid}

const ANARIArray1D = Ptr{Cvoid}

const ANARIArray2D = Ptr{Cvoid}

const ANARIArray3D = Ptr{Cvoid}

const ANARIFrame = Ptr{Cvoid}

const ANARIFuture = Ptr{Cvoid}

const ANARIGeometry = Ptr{Cvoid}

const ANARIGroup = Ptr{Cvoid}

const ANARIInstance = Ptr{Cvoid}

const ANARILight = Ptr{Cvoid}

const ANARIMaterial = Ptr{Cvoid}

const ANARISampler = Ptr{Cvoid}

const ANARISurface = Ptr{Cvoid}

const ANARIRenderer = Ptr{Cvoid}

const ANARISpatialField = Ptr{Cvoid}

const ANARIVolume = Ptr{Cvoid}

const ANARIWorld = Ptr{Cvoid}

mutable struct ANARIParameter
    name::Cstring
    type::ANARIDataType
    ANARIParameter() = new()
end

mutable struct ANARIParameterValue
    name::Cstring
    type::ANARIDataType
    value::Ptr{Cvoid}
    ANARIParameterValue() = new()
end

# typedef void ( * ANARIMemoryDeleter ) ( const void * userPtr , const void * appMemory )
const ANARIMemoryDeleter = Ptr{Cvoid}

# typedef void ( * ANARIStatusCallback ) ( const void * userPtr , ANARIDevice device , ANARIObject source , ANARIDataType sourceType , ANARIStatusSeverity severity , ANARIStatusCode code , const char * message )
const ANARIStatusCallback = Ptr{Cvoid}

# typedef void ( * ANARIFrameCompletionCallback ) ( const void * userPtr , ANARIDevice device , ANARIFrame frame )
const ANARIFrameCompletionCallback = Ptr{Cvoid}

function anariLoadLibrary(name, statusCallback, statusCallbackUserData)
    @ccall libanari.anariLoadLibrary(name::Cstring, statusCallback::ANARIStatusCallback, statusCallbackUserData::Ptr{Cvoid})::ANARILibrary
end

function anariUnloadLibrary(_module)
    @ccall libanari.anariUnloadLibrary(_module::ANARILibrary)::Cvoid
end

function anariLoadModule(library, name)
    @ccall libanari.anariLoadModule(library::ANARILibrary, name::Cstring)::Cvoid
end

function anariUnloadModule(library, name)
    @ccall libanari.anariUnloadModule(library::ANARILibrary, name::Cstring)::Cvoid
end

function anariNewDevice(library, type)
    @ccall libanari.anariNewDevice(library::ANARILibrary, type::Cstring)::ANARIDevice
end

function anariNewInitializedDevice(library, type, initializers)
    @ccall libanari.anariNewInitializedDevice(library::ANARILibrary, type::Cstring, initializers::Ptr{ANARIParameterValue})::ANARIDevice
end

function anariNewArray1D(device, appMemory, deleter, userData, dataType, numElements1)
    @ccall libanari.anariNewArray1D(device::ANARIDevice, appMemory::Ptr{Cvoid}, deleter::ANARIMemoryDeleter, userData::Ptr{Cvoid}, dataType::ANARIDataType, numElements1::UInt64)::ANARIArray1D
end

function anariNewArray2D(device, appMemory, deleter, userData, dataType, numElements1, numElements2)
    @ccall libanari.anariNewArray2D(device::ANARIDevice, appMemory::Ptr{Cvoid}, deleter::ANARIMemoryDeleter, userData::Ptr{Cvoid}, dataType::ANARIDataType, numElements1::UInt64, numElements2::UInt64)::ANARIArray2D
end

function anariNewArray3D(device, appMemory, deleter, userData, dataType, numElements1, numElements2, numElements3)
    @ccall libanari.anariNewArray3D(device::ANARIDevice, appMemory::Ptr{Cvoid}, deleter::ANARIMemoryDeleter, userData::Ptr{Cvoid}, dataType::ANARIDataType, numElements1::UInt64, numElements2::UInt64, numElements3::UInt64)::ANARIArray3D
end

function anariMapArray(device, array)
    @ccall libanari.anariMapArray(device::ANARIDevice, array::ANARIArray)::Ptr{Cvoid}
end

function anariUnmapArray(device, array)
    @ccall libanari.anariUnmapArray(device::ANARIDevice, array::ANARIArray)::Cvoid
end

function anariNewLight(device, type)
    @ccall libanari.anariNewLight(device::ANARIDevice, type::Cstring)::ANARILight
end

function anariNewCamera(device, type)
    @ccall libanari.anariNewCamera(device::ANARIDevice, type::Cstring)::ANARICamera
end

function anariNewGeometry(device, type)
    @ccall libanari.anariNewGeometry(device::ANARIDevice, type::Cstring)::ANARIGeometry
end

function anariNewSpatialField(device, type)
    @ccall libanari.anariNewSpatialField(device::ANARIDevice, type::Cstring)::ANARISpatialField
end

function anariNewVolume(device, type)
    @ccall libanari.anariNewVolume(device::ANARIDevice, type::Cstring)::ANARIVolume
end

function anariNewSurface(device)
    @ccall libanari.anariNewSurface(device::ANARIDevice)::ANARISurface
end

function anariNewMaterial(device, type)
    @ccall libanari.anariNewMaterial(device::ANARIDevice, type::Cstring)::ANARIMaterial
end

function anariNewSampler(device, type)
    @ccall libanari.anariNewSampler(device::ANARIDevice, type::Cstring)::ANARISampler
end

function anariNewGroup(device)
    @ccall libanari.anariNewGroup(device::ANARIDevice)::ANARIGroup
end

function anariNewInstance(device, type)
    @ccall libanari.anariNewInstance(device::ANARIDevice, type::Cstring)::ANARIInstance
end

function anariNewWorld(device)
    @ccall libanari.anariNewWorld(device::ANARIDevice)::ANARIWorld
end

function anariNewObject(device, objectType, type)
    @ccall libanari.anariNewObject(device::ANARIDevice, objectType::Cstring, type::Cstring)::ANARIObject
end

function anariSetParameter(device, object, name, dataType, mem)
    @ccall libanari.anariSetParameter(device::ANARIDevice, object::ANARIObject, name::Cstring, dataType::ANARIDataType, mem::Ptr{Cvoid})::Cvoid
end

function anariUnsetParameter(device, object, name)
    @ccall libanari.anariUnsetParameter(device::ANARIDevice, object::ANARIObject, name::Cstring)::Cvoid
end

function anariUnsetAllParameters(device, object)
    @ccall libanari.anariUnsetAllParameters(device::ANARIDevice, object::ANARIObject)::Cvoid
end

function anariMapParameterArray1D(device, object, name, dataType, numElements1, elementStride)
    @ccall libanari.anariMapParameterArray1D(device::ANARIDevice, object::ANARIObject, name::Cstring, dataType::ANARIDataType, numElements1::UInt64, elementStride::Ptr{UInt64})::Ptr{Cvoid}
end

function anariMapParameterArray2D(device, object, name, dataType, numElements1, numElements2, elementStride)
    @ccall libanari.anariMapParameterArray2D(device::ANARIDevice, object::ANARIObject, name::Cstring, dataType::ANARIDataType, numElements1::UInt64, numElements2::UInt64, elementStride::Ptr{UInt64})::Ptr{Cvoid}
end

function anariMapParameterArray3D(device, object, name, dataType, numElements1, numElements2, numElements3, elementStride)
    @ccall libanari.anariMapParameterArray3D(device::ANARIDevice, object::ANARIObject, name::Cstring, dataType::ANARIDataType, numElements1::UInt64, numElements2::UInt64, numElements3::UInt64, elementStride::Ptr{UInt64})::Ptr{Cvoid}
end

function anariUnmapParameterArray(device, object, name)
    @ccall libanari.anariUnmapParameterArray(device::ANARIDevice, object::ANARIObject, name::Cstring)::Cvoid
end

function anariCommitParameters(device, object)
    @ccall libanari.anariCommitParameters(device::ANARIDevice, object::ANARIObject)::Cvoid
end

function anariRelease(device, object)
    @ccall libanari.anariRelease(device::ANARIDevice, object::ANARIObject)::Cvoid
end

function anariRetain(device, object)
    @ccall libanari.anariRetain(device::ANARIDevice, object::ANARIObject)::Cvoid
end

function anariGetDeviceSubtypes(library)
    @ccall libanari.anariGetDeviceSubtypes(library::ANARILibrary)::Ptr{Cstring}
end

function anariGetDeviceExtensions(library, deviceSubtype)
    @ccall libanari.anariGetDeviceExtensions(library::ANARILibrary, deviceSubtype::Cstring)::Ptr{Cstring}
end

function anariGetObjectSubtypes(device, objectType)
    @ccall libanari.anariGetObjectSubtypes(device::ANARIDevice, objectType::ANARIDataType)::Ptr{Cstring}
end

function anariGetObjectInfo(device, objectType, objectSubtype, infoName, infoType)
    @ccall libanari.anariGetObjectInfo(device::ANARIDevice, objectType::ANARIDataType, objectSubtype::Cstring, infoName::Cstring, infoType::ANARIDataType)::Ptr{Cvoid}
end

function anariGetParameterInfo(device, objectType, objectSubtype, parameterName, parameterType, infoName, infoType)
    @ccall libanari.anariGetParameterInfo(device::ANARIDevice, objectType::ANARIDataType, objectSubtype::Cstring, parameterName::Cstring, parameterType::ANARIDataType, infoName::Cstring, infoType::ANARIDataType)::Ptr{Cvoid}
end

function anariGetProperty(device, object, name, type, mem, size, mask)
    @ccall libanari.anariGetProperty(device::ANARIDevice, object::ANARIObject, name::Cstring, type::ANARIDataType, mem::Ptr{Cvoid}, size::UInt64, mask::ANARIWaitMask)::Cint
end

function anariNewFrame(device)
    @ccall libanari.anariNewFrame(device::ANARIDevice)::ANARIFrame
end

function anariMapFrame(device, frame, channel, width, height, pixelType)
    @ccall libanari.anariMapFrame(device::ANARIDevice, frame::ANARIFrame, channel::Cstring, width::Ptr{UInt32}, height::Ptr{UInt32}, pixelType::Ptr{ANARIDataType})::Ptr{Cvoid}
end

function anariUnmapFrame(device, frame, channel)
    @ccall libanari.anariUnmapFrame(device::ANARIDevice, frame::ANARIFrame, channel::Cstring)::Cvoid
end

function anariNewRenderer(device, type)
    @ccall libanari.anariNewRenderer(device::ANARIDevice, type::Cstring)::ANARIRenderer
end

function anariRenderFrame(device, frame)
    @ccall libanari.anariRenderFrame(device::ANARIDevice, frame::ANARIFrame)::Cvoid
end

function anariFrameReady(device, frame, mask)
    @ccall libanari.anariFrameReady(device::ANARIDevice, frame::ANARIFrame, mask::ANARIWaitMask)::Cint
end

function anariDiscardFrame(device, frame)
    @ccall libanari.anariDiscardFrame(device::ANARIDevice, frame::ANARIFrame)::Cvoid
end

const NULL = 0

const ANARI_INVALID_HANDLE = NULL

const ANARI_SDK_VERSION_MAJOR = 0

const ANARI_SDK_VERSION_MINOR = 15

const ANARI_SDK_VERSION_PATCH = 0

ANARI_DATA_TYPE_DEFINE(v) = ANARIDataType(v)

const ANARI_UNKNOWN = ANARI_DATA_TYPE_DEFINE(0)

const ANARI_DATA_TYPE = ANARI_DATA_TYPE_DEFINE(100)

const ANARI_STRING = ANARI_DATA_TYPE_DEFINE(101)

const ANARI_VOID_POINTER = ANARI_DATA_TYPE_DEFINE(102)

const ANARI_BOOL = ANARI_DATA_TYPE_DEFINE(103)

const ANARI_STRING_LIST = ANARI_DATA_TYPE_DEFINE(150)

const ANARI_DATA_TYPE_LIST = ANARI_DATA_TYPE_DEFINE(151)

const ANARI_PARAMETER_LIST = ANARI_DATA_TYPE_DEFINE(152)

const ANARI_FUNCTION_POINTER = ANARI_DATA_TYPE_DEFINE(200)

const ANARI_MEMORY_DELETER = ANARI_DATA_TYPE_DEFINE(201)

const ANARI_STATUS_CALLBACK = ANARI_DATA_TYPE_DEFINE(202)

const ANARI_LIBRARY = ANARI_DATA_TYPE_DEFINE(500)

const ANARI_DEVICE = ANARI_DATA_TYPE_DEFINE(501)

const ANARI_OBJECT = ANARI_DATA_TYPE_DEFINE(502)

const ANARI_ARRAY = ANARI_DATA_TYPE_DEFINE(503)

const ANARI_ARRAY1D = ANARI_DATA_TYPE_DEFINE(504)

const ANARI_ARRAY2D = ANARI_DATA_TYPE_DEFINE(505)

const ANARI_ARRAY3D = ANARI_DATA_TYPE_DEFINE(506)

const ANARI_CAMERA = ANARI_DATA_TYPE_DEFINE(507)

const ANARI_FRAME = ANARI_DATA_TYPE_DEFINE(508)

const ANARI_GEOMETRY = ANARI_DATA_TYPE_DEFINE(509)

const ANARI_GROUP = ANARI_DATA_TYPE_DEFINE(510)

const ANARI_INSTANCE = ANARI_DATA_TYPE_DEFINE(511)

const ANARI_LIGHT = ANARI_DATA_TYPE_DEFINE(512)

const ANARI_MATERIAL = ANARI_DATA_TYPE_DEFINE(513)

const ANARI_RENDERER = ANARI_DATA_TYPE_DEFINE(514)

const ANARI_SURFACE = ANARI_DATA_TYPE_DEFINE(515)

const ANARI_SAMPLER = ANARI_DATA_TYPE_DEFINE(516)

const ANARI_SPATIAL_FIELD = ANARI_DATA_TYPE_DEFINE(517)

const ANARI_VOLUME = ANARI_DATA_TYPE_DEFINE(518)

const ANARI_WORLD = ANARI_DATA_TYPE_DEFINE(519)

const ANARI_INT8 = ANARI_DATA_TYPE_DEFINE(1000)

const ANARI_INT8_VEC2 = ANARI_DATA_TYPE_DEFINE(1001)

const ANARI_INT8_VEC3 = ANARI_DATA_TYPE_DEFINE(1002)

const ANARI_INT8_VEC4 = ANARI_DATA_TYPE_DEFINE(1003)

const ANARI_UINT8 = ANARI_DATA_TYPE_DEFINE(1004)

const ANARI_UINT8_VEC2 = ANARI_DATA_TYPE_DEFINE(1005)

const ANARI_UINT8_VEC3 = ANARI_DATA_TYPE_DEFINE(1006)

const ANARI_UINT8_VEC4 = ANARI_DATA_TYPE_DEFINE(1007)

const ANARI_INT16 = ANARI_DATA_TYPE_DEFINE(1008)

const ANARI_INT16_VEC2 = ANARI_DATA_TYPE_DEFINE(1009)

const ANARI_INT16_VEC3 = ANARI_DATA_TYPE_DEFINE(1010)

const ANARI_INT16_VEC4 = ANARI_DATA_TYPE_DEFINE(1011)

const ANARI_UINT16 = ANARI_DATA_TYPE_DEFINE(1012)

const ANARI_UINT16_VEC2 = ANARI_DATA_TYPE_DEFINE(1013)

const ANARI_UINT16_VEC3 = ANARI_DATA_TYPE_DEFINE(1014)

const ANARI_UINT16_VEC4 = ANARI_DATA_TYPE_DEFINE(1015)

const ANARI_INT32 = ANARI_DATA_TYPE_DEFINE(1016)

const ANARI_INT32_VEC2 = ANARI_DATA_TYPE_DEFINE(1017)

const ANARI_INT32_VEC3 = ANARI_DATA_TYPE_DEFINE(1018)

const ANARI_INT32_VEC4 = ANARI_DATA_TYPE_DEFINE(1019)

const ANARI_UINT32 = ANARI_DATA_TYPE_DEFINE(1020)

const ANARI_UINT32_VEC2 = ANARI_DATA_TYPE_DEFINE(1021)

const ANARI_UINT32_VEC3 = ANARI_DATA_TYPE_DEFINE(1022)

const ANARI_UINT32_VEC4 = ANARI_DATA_TYPE_DEFINE(1023)

const ANARI_INT64 = ANARI_DATA_TYPE_DEFINE(1024)

const ANARI_INT64_VEC2 = ANARI_DATA_TYPE_DEFINE(1025)

const ANARI_INT64_VEC3 = ANARI_DATA_TYPE_DEFINE(1026)

const ANARI_INT64_VEC4 = ANARI_DATA_TYPE_DEFINE(1027)

const ANARI_UINT64 = ANARI_DATA_TYPE_DEFINE(1028)

const ANARI_UINT64_VEC2 = ANARI_DATA_TYPE_DEFINE(1029)

const ANARI_UINT64_VEC3 = ANARI_DATA_TYPE_DEFINE(1030)

const ANARI_UINT64_VEC4 = ANARI_DATA_TYPE_DEFINE(1031)

const ANARI_FIXED8 = ANARI_DATA_TYPE_DEFINE(1032)

const ANARI_FIXED8_VEC2 = ANARI_DATA_TYPE_DEFINE(1033)

const ANARI_FIXED8_VEC3 = ANARI_DATA_TYPE_DEFINE(1034)

const ANARI_FIXED8_VEC4 = ANARI_DATA_TYPE_DEFINE(1035)

const ANARI_UFIXED8 = ANARI_DATA_TYPE_DEFINE(1036)

const ANARI_UFIXED8_VEC2 = ANARI_DATA_TYPE_DEFINE(1037)

const ANARI_UFIXED8_VEC3 = ANARI_DATA_TYPE_DEFINE(1038)

const ANARI_UFIXED8_VEC4 = ANARI_DATA_TYPE_DEFINE(1039)

const ANARI_FIXED16 = ANARI_DATA_TYPE_DEFINE(1040)

const ANARI_FIXED16_VEC2 = ANARI_DATA_TYPE_DEFINE(1041)

const ANARI_FIXED16_VEC3 = ANARI_DATA_TYPE_DEFINE(1042)

const ANARI_FIXED16_VEC4 = ANARI_DATA_TYPE_DEFINE(1043)

const ANARI_UFIXED16 = ANARI_DATA_TYPE_DEFINE(1044)

const ANARI_UFIXED16_VEC2 = ANARI_DATA_TYPE_DEFINE(1045)

const ANARI_UFIXED16_VEC3 = ANARI_DATA_TYPE_DEFINE(1046)

const ANARI_UFIXED16_VEC4 = ANARI_DATA_TYPE_DEFINE(1047)

const ANARI_FIXED32 = ANARI_DATA_TYPE_DEFINE(1048)

const ANARI_FIXED32_VEC2 = ANARI_DATA_TYPE_DEFINE(1049)

const ANARI_FIXED32_VEC3 = ANARI_DATA_TYPE_DEFINE(1050)

const ANARI_FIXED32_VEC4 = ANARI_DATA_TYPE_DEFINE(1051)

const ANARI_UFIXED32 = ANARI_DATA_TYPE_DEFINE(1052)

const ANARI_UFIXED32_VEC2 = ANARI_DATA_TYPE_DEFINE(1053)

const ANARI_UFIXED32_VEC3 = ANARI_DATA_TYPE_DEFINE(1054)

const ANARI_UFIXED32_VEC4 = ANARI_DATA_TYPE_DEFINE(1055)

const ANARI_FIXED64 = ANARI_DATA_TYPE_DEFINE(1056)

const ANARI_FIXED64_VEC2 = ANARI_DATA_TYPE_DEFINE(1057)

const ANARI_FIXED64_VEC3 = ANARI_DATA_TYPE_DEFINE(1058)

const ANARI_FIXED64_VEC4 = ANARI_DATA_TYPE_DEFINE(1059)

const ANARI_UFIXED64 = ANARI_DATA_TYPE_DEFINE(1060)

const ANARI_UFIXED64_VEC2 = ANARI_DATA_TYPE_DEFINE(1061)

const ANARI_UFIXED64_VEC3 = ANARI_DATA_TYPE_DEFINE(1062)

const ANARI_UFIXED64_VEC4 = ANARI_DATA_TYPE_DEFINE(1063)

const ANARI_FLOAT16 = ANARI_DATA_TYPE_DEFINE(1064)

const ANARI_FLOAT16_VEC2 = ANARI_DATA_TYPE_DEFINE(1065)

const ANARI_FLOAT16_VEC3 = ANARI_DATA_TYPE_DEFINE(1066)

const ANARI_FLOAT16_VEC4 = ANARI_DATA_TYPE_DEFINE(1067)

const ANARI_FLOAT32 = ANARI_DATA_TYPE_DEFINE(1068)

const ANARI_FLOAT32_VEC2 = ANARI_DATA_TYPE_DEFINE(1069)

const ANARI_FLOAT32_VEC3 = ANARI_DATA_TYPE_DEFINE(1070)

const ANARI_FLOAT32_VEC4 = ANARI_DATA_TYPE_DEFINE(1071)

const ANARI_FLOAT64 = ANARI_DATA_TYPE_DEFINE(1072)

const ANARI_FLOAT64_VEC2 = ANARI_DATA_TYPE_DEFINE(1073)

const ANARI_FLOAT64_VEC3 = ANARI_DATA_TYPE_DEFINE(1074)

const ANARI_FLOAT64_VEC4 = ANARI_DATA_TYPE_DEFINE(1075)

const ANARI_UFIXED8_RGBA_SRGB = ANARI_DATA_TYPE_DEFINE(2003)

const ANARI_UFIXED8_RGB_SRGB = ANARI_DATA_TYPE_DEFINE(2002)

const ANARI_UFIXED8_RA_SRGB = ANARI_DATA_TYPE_DEFINE(2001)

const ANARI_UFIXED8_R_SRGB = ANARI_DATA_TYPE_DEFINE(2000)

const ANARI_INT32_BOX1 = ANARI_DATA_TYPE_DEFINE(2004)

const ANARI_INT32_BOX2 = ANARI_DATA_TYPE_DEFINE(2005)

const ANARI_INT32_BOX3 = ANARI_DATA_TYPE_DEFINE(2006)

const ANARI_INT32_BOX4 = ANARI_DATA_TYPE_DEFINE(2007)

const ANARI_FLOAT32_BOX1 = ANARI_DATA_TYPE_DEFINE(2008)

const ANARI_FLOAT32_BOX2 = ANARI_DATA_TYPE_DEFINE(2009)

const ANARI_FLOAT32_BOX3 = ANARI_DATA_TYPE_DEFINE(2010)

const ANARI_FLOAT32_BOX4 = ANARI_DATA_TYPE_DEFINE(2011)

const ANARI_FLOAT64_BOX1 = ANARI_DATA_TYPE_DEFINE(2208)

const ANARI_FLOAT64_BOX2 = ANARI_DATA_TYPE_DEFINE(2209)

const ANARI_FLOAT64_BOX3 = ANARI_DATA_TYPE_DEFINE(2210)

const ANARI_FLOAT64_BOX4 = ANARI_DATA_TYPE_DEFINE(2211)

const ANARI_UINT64_REGION1 = ANARI_DATA_TYPE_DEFINE(2104)

const ANARI_UINT64_REGION2 = ANARI_DATA_TYPE_DEFINE(2105)

const ANARI_UINT64_REGION3 = ANARI_DATA_TYPE_DEFINE(2106)

const ANARI_UINT64_REGION4 = ANARI_DATA_TYPE_DEFINE(2107)

const ANARI_FLOAT32_MAT2 = ANARI_DATA_TYPE_DEFINE(2012)

const ANARI_FLOAT32_MAT3 = ANARI_DATA_TYPE_DEFINE(2013)

const ANARI_FLOAT32_MAT4 = ANARI_DATA_TYPE_DEFINE(2014)

const ANARI_FLOAT32_MAT2x3 = ANARI_DATA_TYPE_DEFINE(2015)

const ANARI_FLOAT32_MAT3x4 = ANARI_DATA_TYPE_DEFINE(2016)

const ANARI_FLOAT32_QUAT_IJKW = ANARI_DATA_TYPE_DEFINE(2017)

const ANARI_FRAME_COMPLETION_CALLBACK = ANARI_DATA_TYPE_DEFINE(203)

const ANARI_LOG_DEBUG = 1

const ANARI_LOG_INFO = 2

const ANARI_LOG_WARNING = 3

const ANARI_LOG_ERROR = 4

const ANARI_LOG_NONE = 5

const ANARI_NO_WAIT = 0

const ANARI_WAIT = 1

const ANARI_STATUS_NO_ERROR = 0

const ANARI_STATUS_UNKNOWN_ERROR = 1

const ANARI_STATUS_INVALID_ARGUMENT = 2

const ANARI_STATUS_INVALID_OPERATION = 3

const ANARI_STATUS_OUT_OF_MEMORY = 4

const ANARI_STATUS_UNSUPPORTED_DEVICE = 5

const ANARI_STATUS_VERSION_MISMATCH = 6

const ANARI_SEVERITY_FATAL_ERROR = 1

const ANARI_SEVERITY_ERROR = 2

const ANARI_SEVERITY_WARNING = 3

const ANARI_SEVERITY_PERFORMANCE_WARNING = 4

const ANARI_SEVERITY_INFO = 5

const ANARI_SEVERITY_DEBUG = 6

# Skipping MacroDefinition: ANARI_INTERFACE __attribute__ ( ( __visibility__ ( "default" ) ) )

# Skipping MacroDefinition: ANARI_DEPRECATED __attribute__ ( ( deprecated ) )

# exports
const PREFIXES = ["ANARI", "anari"]
for name in names(@__MODULE__; all=true), prefix in PREFIXES
    if startswith(string(name), prefix)
        @eval export $name
    end
end

end # module
