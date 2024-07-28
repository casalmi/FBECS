#ifndef BitArray_bi
#define BitArray_bi

#include once "Serializer.bi"

type BitArrayType
    
    dim Array as ubyte ptr
	dim ArraySize as uinteger<32>
    dim Count as uinteger<32>
    dim BitSize as ubyte
    
	'Serializer requires a default constructor
	declare constructor()
	
    declare constructor(inBitSize as ubyte, inCount as uinteger<32>)
    declare destructor()
    
    declare sub Set(index as uinteger, inVal as ubyte)
    declare function Get(index as uinteger) as uinteger
    
    declare function SizeInBytes() as uinteger
    
    declare function BitMask() as const ubyte
    
    declare function GetUsedMemorySize() as uinteger
    
end type

CREATE_SERIALIZER(BitArrayType, _
	MEMBER_SIMPLE(BitSize), _
	MEMBER_SIMPLE(Count), _
	MEMBER_SIMPLE(ArraySize), _
	MEMBER_DYNAMIC_ARRAY(Array, ArraySize))

#endif
