#ifndef Serializer_bi
#define Serializer_bi

'Create a [de]serializer from a user defined type

#include once "fbc-int/array.bi"
#include once "Stream.bi"
'#include once "Stream.bas" 'Uncomment for single file compilation

#define FB_SERIALIZER

namespace FBSerializer

'-----------------------------------------------------------'
'------------------------CHEAT SHEET------------------------'
'-----------------------------------------------------------'
/'

	 Basic usage for a built in type (integer,string,float,etc) will look like the following, note the @:

	- FBSerializer.SerializeToBinary(@variable, stream)
	- FBSerializer.DeserializeFromBinary(@variable, stream)
	- jsonString = FBSerializer.SerializeToJSON(@variable)

	Basic usage for a UDT will look like the following, note
	you can pass the UDT directly byref, or by pointer with @

	- FBSerializer.SerializeToBinary(UDTVariable, stream)
	- FBSerializer.DeserializeFromBinary(UDTVariable, stream)
	- string (json) = FBSerializer.SerializeToJSON(UDTVariable)
	- string (error) = FBSerializer.ValidateJSON(UDTVariable, stream)
	- string (error) = FBSerializer.DeserializeFromJSON(UDTVariable, stream)

	Basic serializer creation macros:

	Creates the foundation for the serializer
	- #macro CREATE_SERIALIZER(__TYPE, _BODY...)

	Instantiates type members of various kinds
	- #macro MEMBER_SIMPLE(_MEMBER)
	- #macro MEMBER_STATIC_FB_ARRAY(_MEMBER)
	- #macro MEMBER_DYNAMIC_ARRAY(_MEMBER, _COUNT_MEMBER)
	- #macro MEMBER_STATIC_ARRAY(_MEMBER, _COUNT)
	- #macro MEMBER_POINTER(_MEMBER)
	- #macro MEMBER_NAMED_UNION(_MEMBER)

	Custom serializer creation macros:

	Defines the prologue and epilogue of a custom serializer (used together)
	- #macro CUSTOM_SERIALIZER_BEGIN(__TYPE)
	- #macro CUSTOM_SERIALIZER_END()

	Defines the signature and early exit case for a custom serializer (sub)
	- #macro SERIALIZE_TO_BINARY_SIGNATURE(_UDT_PARAM, _STREAM_PARAM)

	Defines the signature and early exit case for a custom deserializer (sub)
	- #macro DESERIALIZE_FROM_BINARY_SIGNATURE(_UDT_PARAM, _STREAM_PARAM)

	Defines the signature and null case for a custom JSON serializer (function)
	Returns a string with the serialized JSON
	- #macro SERIALIZE_TO_JSON_SIGNATURE(_UDT_PARAM)

	Defines the signature for custom validator of JSON against a type (function)
	Returns a string with an error if one occurred, "" otherwise
	- #macro VALIDATE_JSON_SIGNATURE(_UDT_PARAM, _STREAM_PARAM)

	Defines the signature and null case for a custom JSON deserializer (function)
	Returns a string with an error if one occurred, "" otherwise
	- #macro DESERIALIZE_FROM_JSON_SIGNATURE(_UDT_PARAM, _STREAM_PARAM)
	
	'Template for custom serializer:
	CUSTOM_SERIALIZER_BEGIN(_YOUR_TYPE_HERE_)
		
		private sub SERIALIZE_TO_BINARY_SIGNATURE(inUDT, stream)
		end sub
		
		private sub DESERIALIZE_FROM_BINARY_SIGNATURE(inUDT, stream)
		end sub
		
		private function SERIALIZE_TO_JSON_SIGNATURE(inUDt)
			return "{}"
		end function
		
		private function VALIDATE_JSON_SIGNATURE(inUDT, stream)
			return ""
		end function
		
		private function DESERIALIZE_FROM_JSON_SIGNATURE(inUDT, stream)
			return ""
		end function
		
	CUSTOM_SERIALIZER_END()
	
'/
'--------------------------------------------------------------------------'
'------------------------Begin macro implementation------------------------'
'--------------------------------------------------------------------------'

#define GET_SERIALIZER_ARRAY_NAME(__TYPE) ##__TYPE##_SERIALIZER_ARRAY

'Macros that expand to the correct signature for the respective serializer functions
'NOTE: you must declare these as private subs/functions

' -_UDT_PARAM: The name of the UDT pointer parameter passed to the function
' -_STREAM_PARAM: The name of the stream parameter passed to the function

'Serialize to binary (sub)
#macro SERIALIZE_TO_BINARY_SIGNATURE(_UDT_PARAM, _STREAM_PARAM)
SerializeToBinary overload (##_UDT_PARAM as CURRENT_TYPE ptr, _STREAM_PARAM as StreamInterface)
	if _UDT_PARAM = 0 then return: endif
#endmacro

'Deserialize from binary (sub)
#macro DESERIALIZE_FROM_BINARY_SIGNATURE(_UDT_PARAM, _STREAM_PARAM)
DeserializeFromBinary overload (##_UDT_PARAM as CURRENT_TYPE ptr, _STREAM_PARAM as StreamInterface)
	if _UDT_PARAM = 0 then return: endif
#endmacro

'Serialize to JSON (function)
#macro SERIALIZE_TO_JSON_SIGNATURE(_UDT_PARAM)
SerializeToJSON overload (##_UDT_PARAM as CURRENT_TYPE ptr) as string
	if _UDT_PARAM = 0 then return "null": endif
#endmacro

'Validate against JSON (function).  The pointer may be null, but must be the correct type.
#macro VALIDATE_JSON_SIGNATURE(_UDT_PARAM, _STREAM_PARAM)
ValidateJSON overload (##_UDT_PARAM as CURRENT_TYPE ptr, _STREAM_PARAM as StreamInterface) as string
	'Validation does not require a valid pointer
#endmacro

'Deserialize from JSON (function)
#macro DESERIALIZE_FROM_JSON_SIGNATURE(_UDT_PARAM, _STREAM_PARAM)
DeserializeFromJSON overload (##_UDT_PARAM as CURRENT_TYPE ptr, _STREAM_PARAM as StreamInterface) as string
	if _UDT_PARAM = 0 then return "Null pointer passed in": endif
#endmacro

'Used to generate a custom serializer, must be paired with CUSTOM_SERIALIZER_END
#macro CUSTOM_SERIALIZER_BEGIN(__TYPE)
	#ifndef ##__TYPE##_SERIALIZER
	
	'Define cleaned up in CUSTOM_SERIALIZER_END
	#define CURRENT_TYPE __TYPE
	
	namespace FBSerializer
		#define ##__TYPE##_SERIALIZER
#endmacro

'Used to generate a custom serializer, must be preceeded by CUSTOMER_SERIALIZER_BEGIN
#macro CUSTOM_SERIALIZER_END()
	
		'Automatically generated helper/convenience functions
		
		'The getter for the serialize function (unfortunately necessary)
		private function GetSerializeToBinary overload (inVal as CURRENT_TYPE ptr) as sub(as any ptr, byref stream as StreamInterface)
			return cast(sub(as any ptr, byref stream as StreamInterface), _
				procptr(FBSerializer.SerializeToBinary, sub(as CURRENT_TYPE ptr, byref stream as StreamInterface)))
		end function

		'A convenience interface for serialization
		private sub SerializeToBinary overload (byref inUDT as CURRENT_TYPE, byref stream as StreamInterface)
			FBSerializer.SerializeToBinary(@inUDT, stream)
		end sub
		
		'The getter for the deserialize function
		private function GetDeserializeFromBinary overload (inVal as CURRENT_TYPE ptr) as sub(as any ptr, byref stream as StreamInterface)
			return cast(sub(as any ptr, byref stream as StreamInterface), _
				procptr(FBSerializer.DeserializeFromBinary, sub(as CURRENT_TYPE ptr, byref stream as StreamInterface)))
		end function
		
		'A convenience interface for deserialization
		private sub DeserializeFromBinary overload (byref inUDT as CURRENT_TYPE, byref stream as StreamInterface)
			FBSerializer.DeserializeFromBinary(@inUDT, stream)
		end sub
		
		'The getter for the serialize to JSON function
		private function GetSerializeToJSON overload (inVal as CURRENT_TYPE ptr) as function(as any ptr) as string
			return cast(function(as any ptr) as string, _
				procptr(FBSerializer.SerializeToJSON, function(as CURRENT_TYPE ptr) as string))
		end function
		
		'A convenience interface for serializing to JSON
		private function SerializeToJSON overload (byref inUDT as CURRENT_TYPE) as string
			return FBSerializer.SerializeToJSON(@inUDT)
		end function
		
		'The getter for the JSON validation function
		private function GetValidateJSON overload (inVal as CURRENT_TYPE ptr) as function(as any ptr, byref stream as StreamInterface) as string
			return cast(function(as any ptr, byref stream as StreamInterface) as string, _
				procptr(FBSerializer.ValidateJSON, function(as CURRENT_TYPE ptr, byref stream as StreamInterface) as string))
		end function
		
		'A convenience interface for validation
		private function ValidateJSON overload (byref inUDT as CURRENT_TYPE, byref stream as StreamInterface) as string
			return FBSerializer.ValidateJSON(@inUDT, stream)
		end function
		
		private function GetDeserializeFromJSON overload (inVal as CURRENT_TYPE ptr) as function(as any ptr, byref stream as StreamInterface) as string
			return cast(function(as any ptr, byref stream as StreamInterface) as string, _
				procptr(FBSerializer.DeserializeFromJSON, function(as CURRENT_TYPE ptr, byref stream as StreamInterface) as string))
		end function
		
		private function DeserializeFromJSON overload (byref inUDT as CURRENT_TYPE, byref stream as StreamInterface) as string
			return FBSerializer.DeserializeFromJSON(@inUDT, stream)
		end function
		
		private function TypeAllocator overload (unused as CURRENT_TYPE ptr, inCount as integer) as any ptr
			'This should ensure any allocation uses the correct type
			'and any associated default constructor is called
			'The also means you should use delete()/delete [] for pointers
			'created through deserialization that have dynamic allocation
			
			'TODO: If a default constructor exists and allocates memory, what do?  Delete it?
			return new CURRENT_TYPE
		end function
		
		private function GetTypeAllocator overload (unused as CURRENT_TYPE ptr) as function(as any ptr, as integer) as any ptr
			return cast(function(as any ptr, as integer) as any ptr, _
				procptr(FBSerializer.TypeAllocator, function(as CURRENT_TYPE ptr, as integer) as any ptr))
		end function
		
		private function TypeArrayAllocator overload (unused as CURRENT_TYPE ptr, inCount as integer) as any ptr
			'This should ensure any allocation uses the correct type
			'and any associated default constructor is called
			'The also means you should use delete [] for arrays
			'created through deserialization that have dynamic allocation
			return new CURRENT_TYPE[inCount]
		end function
		
		private function GetTypeArrayAllocator overload (unused as CURRENT_TYPE ptr) as function(as any ptr, as integer) as any ptr
			return cast(function(as any ptr, as integer) as any ptr, _
				procptr(FBSerializer.TypeArrayAllocator, function(as CURRENT_TYPE ptr, as integer) as any ptr))
		end function

	end namespace
	
	#undef CURRENT_TYPE
	
#endif
#endmacro

'Declare the necessary bits that define a serializer
'A serializer cannot be created in a namespace
' __TYPE: UDT name
' _BODY: List of MEMBER_... entries
#macro CREATE_SERIALIZER(__TYPE, _BODY...)
#ifndef ##__TYPE##_SERIALIZER
	#define CURRENT_TYPE __TYPE
	
	dim shared GET_SERIALIZER_ARRAY_NAME(__TYPE)(...) as FBSerializer.SerializerMemberInfoType = _
		{ _BODY }
	
	#undef CURRENT_TYPE
	
	CUSTOM_SERIALIZER_BEGIN(__TYPE)
		
		'The serialize function
		private sub SERIALIZE_TO_BINARY_SIGNATURE(inUDT, stream)
			FBSerializer.SToBinary(inUDT, GET_SERIALIZER_ARRAY_NAME(__TYPE)(), stream)
		end sub
		
		'The deserialize function
		private sub DESERIALIZE_FROM_BINARY_SIGNATURE(inUDT, stream)
			FBSerializer.DFromBinary(inUDT, GET_SERIALIZER_ARRAY_NAME(__TYPE)(), stream)
		end sub
		
		'The json serializer
		private function SERIALIZE_TO_JSON_SIGNATURE(inUDT)		
			return FBSerializer.SToJson(inUDT, GET_SERIALIZER_ARRAY_NAME(__TYPE)())
		end function
		
		private function VALIDATE_JSON_SIGNATURE(inUDT, stream)
			return FBSerializer.VFromJSON(GET_SERIALIZER_ARRAY_NAME(__TYPE)(), stream)
		end function
		
		private function DESERIALIZE_FROM_JSON_SIGNATURE(inUDT, stream)
			return FBSerializer.DFromJSON(inUDT, GET_SERIALIZER_ARRAY_NAME(__TYPE)(), stream)
		end function
	
	CUSTOM_SERIALIZER_END()
	
#endif
#endmacro

'Simple data type that doesn't require special care.
'This is any type (including UDTs set up for serialization) that is NOT:
' - A Freebasic built-in array
' - A pointer of any kind (array or reference)
' - A union
#macro MEMBER_SIMPLE(_MEMBER)
	FBSerializer.SerializerMemberInfoType( _
		FBSerializer.SerializerMemberInfoType._SIMPLE, _
		sizeof(##CURRENT_TYPE.##_MEMBER), _
		offsetof(##CURRENT_TYPE, ##_MEMBER), _
		cast(zstring ptr, @#_MEMBER), _
		FBSerializer.GetSerializeToBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		FBSerializer.GetDeserializeFromBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		FBSerializer.GetSerializeToJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		FBSerializer.GetValidateJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		FBSerializer.GetDeserializeFromJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)))		
#endmacro

#macro MEMBER_STATIC_FB_ARRAY(_MEMBER)
	FBSerializer.SerializerMemberInfoType( _
		FBSerializer.SerializerMemberInfoType._STATIC_FB_ARRAY, _
		0, _
		offsetof(##CURRENT_TYPE, ##_MEMBER(0)), _
		cast(zstring ptr, @#_MEMBER), _
		FBSerializer.GetSerializeToBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		FBSerializer.GetDeserializeFromBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		FBSerializer.GetSerializeToJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		FBSerializer.GetValidateJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		FBSerializer.GetDeserializeFromJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER) ptr, 0)), _
		0, _ 'Subtype size is in FBC.FBARRAY.element_len
		0, _
		FBC.ArrayConstDescriptorPtr(cast(typeof(##CURRENT_TYPE) ptr, 0)->##_MEMBER()))
#endmacro

#macro MEMBER_DYNAMIC_ARRAY(_MEMBER, _COUNT_MEMBER)
	FBSerializer.SerializerMemberInfoType( _
		FBSerializer.SerializerMemberInfoType._PTR_ARRAY, _
		sizeof(##CURRENT_TYPE.##_MEMBER), _
		offsetof(##CURRENT_TYPE, ##_MEMBER), _
		cast(zstring ptr, @#_MEMBER), _
		FBSerializer.GetSerializeToBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetDeserializeFromBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetSerializeToJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetValidateJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetDeserializeFromJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		sizeof(typeof(*cast(typeof(##CURRENT_TYPE.##_MEMBER), 0))), _
		FBSerializer.GetTypeArrayAllocator(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		0, _
		0, _
		sizeof(##CURRENT_TYPE.##_COUNT_MEMBER), _
		offsetof(##CURRENT_TYPE, ##_COUNT_MEMBER))
#endmacro

#macro MEMBER_STATIC_ARRAY(_MEMBER, _COUNT)
	FBSerializer.SerializerMemberInfoType( _
		FBSerializer.SerializerMemberInfoType._PTR_ARRAY, _
		sizeof(##CURRENT_TYPE.##_MEMBER), _
		offsetof(##CURRENT_TYPE, ##_MEMBER), _
		cast(zstring ptr, @#_MEMBER), _
		FBSerializer.GetSerializeToBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetDeserializeFromBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetSerializeToJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetValidateJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetDeserializeFromJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		sizeof(##CURRENT_TYPE.##_MEMBER), _
		FBSerializer.GetTypeArrayAllocator(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		0, _
		_COUNT)
#endmacro

#macro MEMBER_POINTER(_MEMBER)
	FBSerializer.SerializerMemberInfoType( _
		FBSerializer.SerializerMemberInfoType._POINTER, _
		sizeof(##CURRENT_TYPE.##_MEMBER), _
		offsetof(##CURRENT_TYPE, ##_MEMBER), _
		cast(zstring ptr, @#_MEMBER), _
		FBSerializer.GetSerializeToBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetDeserializeFromBinary(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetSerializeToJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetValidateJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		FBSerializer.GetDeserializeFromJSON(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)), _
		sizeof(typeof(*cast(typeof(##CURRENT_TYPE.##_MEMBER), 0))), _
		FBSerializer.GetTypeAllocator(cast(typeof(##CURRENT_TYPE.##_MEMBER), 0)))
#endmacro

#macro MEMBER_NAMED_UNION(_MEMBER)
	FBSerializer.SerializerMemberInfoType( _
		FBSerializer.SerializerMemberInfoType._UNION, _
		sizeof(##CURRENT_TYPE.##_MEMBER), _
		offsetof(##CURRENT_TYPE, ##_MEMBER), _
		cast(zstring ptr, @#_MEMBER), _
		0, _
		0, _
		0, _
		0, _
		0)
#endmacro

type SerializerMemberInfoType

	enum MemberTypeEnum
		_UNSET = 0        'Reserved
		_SIMPLE           'An uncomplicated type
		_FIXED_STRING     'Freebasic built-in string with fixed size.  Needs to be handled special because it's special...
		_STATIC_FB_ARRAY  'Freebasic built-in array type with fixed length (e.g. array(10) or array(5 to 15, 0 to 5) etc)
		_DYNAMIC_FB_ARRAY 'Freebasic built-in array type with dynamic length (e.g. array(any)) TODO: implement?
		_PTR_ARRAY        'Pointer representing an array
		_POINTER          'Any other pointer type
		_UNION            'Named union type, handled as blittable data
		_LAST_TYPE        'End of list identifier
	end enum
	
	'Base type descriptor
	type TypeDescriptorType
		dim as MemberTypeEnum _Type
		dim as uinteger<32> Size
		dim as integer<32> Offset
	end type
	
	'Sub type descriptor
	type SubTypeType
		'Subtype descriptor
		dim as uinteger<32> Size
		
		'A function that directly allocates the subtype using New []
		dim as function(as any ptr, as integer) as any ptr Allocator
	end type

	'Pointer based array type
	'A pointer based array will fill in either the Count
	'or the Size/CountPtrOffset.  Not both.
	type PtrArrayDescriptorType
		'Static count
		dim as uinteger<32> Count
		'Size of the pointer holding the count
		dim as uinteger<32> Size
		'Offset of the count variable from the array's pointer
		dim as integer<32> CountPtrOffset
	end type


	'''''''''''''''''''''''''Type Members'''''''''''''''''''''''''

	'The base type
	dim as TypeDescriptorType BaseType
	'The name of the type member
	dim as zstring ptr BaseName
	
	'Pointer to the overloaded serializer function
	dim as sub(as any ptr, byref as StreamInterface) Serializer
	'Pointer to the overloaded deserializer function
	dim as sub(as any ptr, byref as StreamInterface) Deserializer
	'Pointer to the overloaded function that converts member to json
	dim as function(as any ptr) as string ToJSON
	'Pointer to the overloaded function that validates json against our type
	dim as function(as any ptr, byref as StreamInterface) as string ValidateJSON
	'Pointer to the overloaded function that deserializes from json in a stream
	dim as function(as any ptr, byref as StreamInterface) as string FromJSON
	
	'Descriptor of a subtype if applicable
	dim as SubTypeType SubType
	
	'One of two array types
	union
		FBArray as FBC.FBARRAY
		PtrArray as PtrArrayDescriptorType
	end union

	declare constructor overload ( _
		inType as MemberTypeEnum, _
		inSize as uinteger<32>, _
		inOffset as integer<32>, _
		inName as zstring ptr, _
		inSerializer as sub(as any ptr, byref as StreamInterface), _
		inDeserializer as sub(as any ptr, byref as StreamInterface), _
		inToJSON as function(as any ptr) as string, _
		inValidateJSON as function(as any ptr, byref as StreamInterface) as string, _
		inFromJSON as function(as any ptr, byref as StreamInterface) as string, _
		inSubTypeSize as uinteger<32> = 0, _
		inSubTypeAllocator as function(as any ptr, as integer) as any ptr = 0, _
		inArrayDescriptorPtr as const FBC.FBARRAY ptr = 0, _
		inArrayCount as uinteger<32> = 0, _
		inArrayCountPointerSize as uinteger<32> = 0, _
		inArrayCountPointerOffset as integer<32> = 0)

	declare destructor()
	
end type

'----------------------------------------------'
'The main functions called for [de]serialization
'----------------------------------------------'
declare function SToJSON( _
		inStruct as any ptr, _
		serializerArray() as const FBSerializer.SerializerMemberInfoType) as string
		
declare function DFromBinary( _
		outStruct as any ptr, _
		serializerArray() as const FBSerializer.SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
		
declare function SToBinary( _
		inStruct as any ptr, _
		serializerArray() as const FBSerializer.SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer

declare function VFromJSON( _
		serializerArray() as const FBSerializer.SerializerMemberInfoType, _
		byref stream as StreamInterface) as string

declare function DFromJSON( _
		outStruct as any ptr, _
		serializerArray() as const FBSerializer.SerializerMemberInfoType, _
		byref stream as StreamInterface) as string

'-----------------------------------------------------------'
'Helper functions to facilitate easier custom [de]serializers
'-----------------------------------------------------------'

'Gets the next non-whitespace token in a stream.
'
'Returns: The next character as a ubyte
' - stream: The stream containing the json text.
declare function GetNextToken(byref stream as StreamInterface) as ubyte

'Gets up to the last 64 characters in the stream with an underscore to help debugging.
'
'Returns: Up to the last 64 characters in a stream with a deliniating underscore and ^
' - stream: The stream containing a json text.
declare function GetErrorContext(byref stream as StreamInterface) as string

'Gets the number of values an array from json text.
'The stream head will be returned to it's original position
'after this function returns unless an error was encountered
'
'Returns: A string of any error or "" if no error
' - stream: The stream containing the json text.  The stream head must point to the start of an array "["
' - outLength: A pointer to an integer which will be set to the array's length
declare function GetJSONArrayLength( _
		byref stream as StreamInterface, _
		outLength as integer ptr) as string

'Reads a json array and automatically calls "inCallback" on each value found.
'The stream head will be left at the byte AFTER the closing ], unless an error was encountered.
'
'Returns: A string of any error or "" if no error
' - stream: The stream containing the json text.  The stream head must point to the start of an array "["
' - outPtr: A pointer to the start of the array that "inCallback" will be sent to
'        - Note this may be 0 if inCallback does not requires a valid pointer.  Used for validation.
' - elementSize: The size of each array element pointed to by outPtr
' - inCallback: A function pointer to a validation/deserialization function
declare function ReadJSONArray( _
		byref stream as StreamInterface, _
		outPtr as any ptr, _
		elementSize as integer, _
		inCallback as function(as any ptr, byref as StreamInterface) as string) as string

'Helps parsing a key + ':' + value + ',' within an object.
'When called, the key is read, the : is read, and then it returns upon
'finding a value.  The readState is updated within the function.  When the
'function returns, one of two things has occured:
' 1) If *outHasValue = 0 then either an error has returned (check return value)
'    or the object close curly brace was encountered "}" and the stream head will
'    be at the byte after that curly brace
' 2) If *outHasValue = 1 then the stream head will be at the start of a value to the key
'readState should not be modified while the object is being iterated over.
'
'Returns: A string of any error or "" if no error.  If error no action should be taken on the out values
' - stream: The stream containing the json text.  The first time this function is called in an object
'        the stream head should be pointing to the first key in the object (the opening quotes ") OR
'        it will point to the end of the object (if the object is completely empty).
' - readState: A reference to the context byte that determines what the function should expect.
'        Set this to 0 the first time you call the function in an object.  Otherwise do not touch it.
' - outKey: A pointer to a string that will be set to the read in key
' - outHasValue: Returns whether or not there is a value to read in.
'        If 0 then either an error occured (check the return value), or the object is finished (encountered a "}")
'        if 1 then the stream head is at the start of the value to the read in key
declare function GetNextJSONKeyValue( _
		byref stream as StreamInterface, _
		byref readState as ubyte, _
		outKey as string ptr, _
		outHasValue as ubyte ptr) as string

'Prints easily readable formatted json
'
'Returns: A string with the formatted json
' - stream: The stream containing the json
' - tabWidth (optional): number of spaces per tab
declare function JSONPrettyPrint overload ( _
		byref stream as StreamInterface, _
		tabWidth as uinteger = 4) as string

'Prints easily readable formatted json from a string
'See above
declare function JSONPrettyPrint overload ( _
		byref inJSON as string, _
		tabWidth as uinteger = 4) as string

'---------------'
'API declarations
'---------------'

'Macros cleaned up at end of file
'Due to what I believe is a bug, ProcPtr does not fully coerce types that are
'set through typeof(variable).  So to get around that, I shuttle access
'of the serializer functions through this function that explicitly sets the type
'that's passed to ProcPtr
#macro DeclareSGet(__TYPE)
declare function GetSerializeToBinary overload (inVal as __TYPE ptr) as sub(as any ptr, byref stream as StreamInterface)
#endmacro

'Same thing, but for deserialization
#macro DeclareDGet(__TYPE)
declare function GetDeserializeFromBinary overload (inVal as __TYPE ptr) as sub(as any ptr, byref stream as StreamInterface)
#endmacro

#macro DeclareSJSONGet(__TYPE)
declare function GetSerializeToJSON overload (inVal as __TYPE ptr) as function(as any ptr) as string
#endmacro

#macro DeclareVJSONGet(__TYPE)
declare function GetValidateJSON overload (inVal as __TYPE ptr) as function(as any ptr, byref as StreamInterface) as string
#endmacro

#macro DeclareDJSONGet(__TYPE)
declare function GetDeserializeFromJSON overload (inVal as __TYPE ptr) as function(as any ptr, byref as StreamInterface) as string
#endmacro

#macro DeclareGetters(__TYPE)
	DeclareSGet(__TYPE)
	DeclareDGet(__TYPE)
	DeclareSJsonGet(__TYPE)
	DeclareVJSONGet(__TYPE)
	DeclareDJSONGet(__TYPE)

	declare function TypeAllocator overload (unused as __TYPE ptr, inCount as integer) as any ptr
	
	declare function GetTypeAllocator overload (inVal as __TYPE ptr) as function(as any ptr, as integer) as any ptr

	declare function TypeArrayAllocator overload (unused as __TYPE ptr, inCount as integer) as any ptr
	
	declare function GetTypeArrayAllocator overload (inVal as __TYPE ptr) as function(as any ptr, as integer) as any ptr

#endmacro

'Boolean
declare sub SerializeToBinary overload (inBool as boolean ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inBool as boolean ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inBool as boolean ptr) as string
declare function ValidateJSON overload (inBool as boolean ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inBool as boolean ptr, byref stream as StreamInterface) as string
DeclareGetters(boolean)

'Byte
declare sub SerializeToBinary overload (inByte as byte ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inByte as byte ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inByte as byte ptr) as string
declare function ValidateJSON overload (inByte as byte ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inByte as byte ptr, byref stream as StreamInterface) as string
DeclareGetters(byte)

declare sub SerializeToBinary overload (inUByte as ubyte ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inUByte as ubyte ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inUByte as ubyte ptr) as string
declare function ValidateJSON overload (inUByte as ubyte ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inUByte as ubyte ptr, byref stream as StreamInterface) as string
DeclareGetters(ubyte)

'Short
declare sub SerializeToBinary overload (inShort as short ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inShort as short ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inShort as short ptr) as string
declare function ValidateJSON overload (inShort as short ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inShort as short ptr, byref stream as StreamInterface) as string
DeclareGetters(short)

declare sub SerializeToBinary overload (inUShort as ushort ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inUShort as ushort ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inUShort as ushort ptr) as string
declare function ValidateJSON overload (inUShort as ushort ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inUShort as ushort ptr, byref stream as StreamInterface) as string
DeclareGetters(ushort)

'Integer<32>
declare sub SerializeToBinary overload (inInt as integer<32> ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inInt as integer<32> ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inInt as integer<32> ptr) as string
declare function ValidateJSON overload (inInt as integer<32> ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inInt as integer<32> ptr, byref stream as StreamInterface) as string
DeclareGetters(integer<32>)

declare sub SerializeToBinary overload (inUInt as uinteger<32> ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inUInt as uinteger<32> ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inUInt as uinteger<32> ptr) as string
declare function ValidateJSON overload (inUInt as uinteger<32> ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inUInt as uinteger<32> ptr, byref stream as StreamInterface) as string
DeclareGetters(uinteger<32>)

'Integer<64>
declare sub SerializeToBinary overload (inInt as integer<64> ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inInt as integer<64> ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inInt as integer<64> ptr) as string
declare function ValidateJSON overload (inInt as integer<64> ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inInt as integer<64> ptr, byref stream as StreamInterface) as string
DeclareGetters(integer<64>)

declare sub SerializeToBinary overload (inUInt as uinteger<64> ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inUInt as uinteger<64> ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inUInt as uinteger<64> ptr) as string
declare function ValidateJSON overload (inUInt as uinteger<64> ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inUInt as uinteger<64> ptr, byref stream as StreamInterface) as string
DeclareGetters(uinteger<64>)

'Architecture dependent Integer
declare sub SerializeToBinary overload (inInt as integer ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inInt as integer ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inInt as integer ptr) as string
declare function ValidateJSON overload (inInt as integer ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inInt as integer ptr, byref stream as StreamInterface) as string
DeclareGetters(integer)

declare sub SerializeToBinary overload (inUInt as uinteger ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inUInt as uinteger ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inUInt as uinteger ptr) as string
declare function ValidateJSON overload (inUInt as uinteger ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inUInt as uinteger ptr, byref stream as StreamInterface) as string
DeclareGetters(uinteger)

'Single
declare sub SerializeToBinary overload (inSingle as single ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inSingle as single ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inSingle as single ptr) as string
declare function ValidateJSON overload (inSingle as single ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inSingle as single ptr, byref stream as StreamInterface) as string
DeclareGetters(single)

'Double
declare sub SerializeToBinary overload (inDouble as double ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inDouble as double ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inDouble as double ptr) as string
declare function ValidateJSON overload (inDouble as double ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inDouble as double ptr, byref stream as StreamInterface) as string
DeclareGetters(double)

'String
declare sub SerializeToBinary overload (inString as string ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inString as string ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inString as string ptr) as string
declare function ValidateJSON overload (inString as string ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inString as string ptr, byref stream as StreamInterface) as string
DeclareGetters(string)

'ZString
declare sub SerializeToBinary overload (inZStringPtr as zstring ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inZStringPtr as zstring ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inZString as zstring ptr) as string
declare function ValidateJSON overload (inZString as zstring ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inZString as zstring ptr, byref stream as StreamInterface) as string
'Fixed length zstrings cannot be dynamically allocated
DeclareSGet(zstring)
DeclareDGet(zstring)
DeclareSJSONGet(zstring)
DeclareVJSONGet(zstring)
DeclareDJSONGet(zstring)

declare sub SerializeToBinary overload (inZStringPtr as zstring ptr ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inZStringPtr as zstring ptr ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inZStringPtr as zstring ptr ptr) as string
declare function ValidateJSON overload (inZStringPtr as zstring ptr ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inZStringPtr as zstring ptr Ptr, byref stream as StreamInterface) as string
DeclareGetters(zstring ptr)

'WString
declare sub SerializeToBinary overload (inWStringPtr as wstring ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inWStringPtr as wstring ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inWString as wstring ptr) as string
declare function ValidateJSON overload (inWString as wstring ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inWString as wstring ptr, byref stream as StreamInterface) as string
'Fixed length wstrings cannot be dynamically allocated
DeclareSGet(wstring)
DeclareDGet(wstring)
DeclareSJSONGet(wstring)
DeclareVJSONGet(wstring)
DeclareDJSONGet(wstring)

declare sub SerializeToBinary overload (inWStringPtr as wstring ptr ptr, byref stream as StreamInterface)
declare sub DeserializeFromBinary overload (inWStringPtr as wstring ptr ptr, byref stream as StreamInterface)
declare function SerializeToJSON overload (inWStringPtr as wstring ptr ptr) as string
declare function ValidateJSON overload (inWStringPtr as wstring ptr ptr, byref stream as StreamInterface) as string
declare function DeserializeFromJSON overload (inWStringPtr as wstring ptr ptr, byref stream as StreamInterface) as string
DeclareGetters(wstring ptr)

'Catch all for any type of pointer
'This one should not be privatized as we need the function pointer to be consistent across all modules
declare sub SerializeToBinary overload (inPtr as any ptr, byref stream as StreamInterface)
DeclareSGet(any)

declare sub DeserializeFromBinary overload (inPtr as any ptr, byref stream as StreamInterface)
DeclareDGet(any)

declare function SerializeToJSON overload (inPtr as any ptr) as string
DeclareSJSONGet(any)

declare function ValidateJSON overload (inPtr as any ptr, byref stream as StreamInterface) as string
DeclareVJSONGet(any)

declare function DeserializeFromJSON overload (inPtr as any ptr, byref stream as StreamInterface) as string
DeclareDJSONGet(any)

#undef DeclareSGet
#undef DeclareDGet
#undef DeclareSJSONGet
#undef DeclareGetters

end namespace

#endif
