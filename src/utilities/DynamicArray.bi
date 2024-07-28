#ifndef DynamicArray_bi
#define DynamicArray_bi

#include once "crt/mem.bi"

'TODO: The fact that this casts the pointer of the index
'instead of doing literally anything else sucks and I need
'to rethink it.
#ifndef DYNAMIC_ARRAY_CAST
#macro DYNAMIC_ARRAY_CAST(casttype, array, index)
    (cast(##casttype, @((##array)[##index])))
#endmacro
#endif

'VALUE returns a reference of type ITEM_TYPE each iteration
#ifndef DYNAMICARRAY_FOREACH_START
#macro DYNAMICARRAY_FOREACH_START(ARRAY, INCR, VALUE, ITEM_TYPE)
scope
if sizeof(##ITEM_TYPE) <> (##ARRAY).ElementSize then
	dprint(__FUNCTION__;" line";__LINE__;": DYNAMICARRAY_FOREACH_START invalid type, size mismatch")
	dprint("Expected: ";(##ARRAY).ElementSize;" got: ";sizeof(##ITEM_TYPE))
	sleep
end if
for ##INCR as integer = 0 to (##ARRAY).Count-1
    dim byref as typeof(##ITEM_TYPE) ##VALUE = *cast(typeof(##ITEM_TYPE) ptr, @((##ARRAY)[(##INCR)]))
#endmacro
#endif

'Iterate in reverse
#ifndef DYNAMICARRAY_FOREACH_START_REV
#macro DYNAMICARRAY_FOREACH_START_REVERSE(ARRAY, INCR, VALUE, ITEM_TYPE)
scope
if sizeof(##ITEM_TYPE) <> (##ARRAY).ElementSize then
	dprint(__FUNCTION__;" line";__LINE__;": DYNAMICARRAY_FOREACH_START invalid type, size mismatch")
	dprint("Expected: ";(##ARRAY).ElementSize;" got: ";sizeof(##ITEM_TYPE))
	sleep
end if
for ##INCR as integer = (##ARRAY).Count-1 to 0 step -1
    dim byref as typeof(##ITEM_TYPE) ##VALUE = *cast(typeof(##ITEM_TYPE) ptr, @((##ARRAY)[(##INCR)]))
#endmacro
#endif

#ifndef DYNAMICARRAY_FOREACH_NEXT
#macro DYNAMICARRAY_FOREACH_NEXT
next
end scope
#endmacro
#endif

#ifndef DYNAMICARRAY_FOREACH_CONTINUE
#macro DYNAMICARRAY_FOREACH_CONTINUE
:continue for:
#endmacro
#endif

type DynamicArrayType
    
    'A dense, auto-resizing array
    
    dim Count as integer<32>
    dim Size as uinteger<32>
    dim ElementSize as uinteger
    
    dim Array as ubyte ptr
    
    'Integers
    declare function Push overload (item as boolean) as uinteger
    declare function Push overload (item as byte) as uinteger
    declare function Push overload (item as ubyte) as uinteger
    declare function Push overload (item as short) as uinteger
    declare function Push overload (item as ushort) as uinteger
    declare function Push overload (item as integer<32>) as uinteger
    declare function Push overload (item as uinteger<32>) as uinteger
    declare function Push overload (item as integer<64>) as uinteger
    declare function Push overload (item as uinteger<64>) as uinteger
    'Floating point
    declare function Push overload (item as single) as uinteger
    declare function Push overload (item as double) as uinteger
    'String type
    declare function Push overload (item as string) as uinteger
    declare function Push overload (item as zstring ptr) as uinteger
    'All pointers
    declare function Push overload (item as any ptr) as uinteger
    
    'Catch all for any other type.
    declare function PushUDT(item as any ptr) as uinteger
    
    'Simply reserves a new index and returns the new index
    declare function Reserve overload () as uinteger
	'Reserves a batch of indexes and returns the first one
	declare function Reserve overload (inCount as uinteger) as uinteger
	'Reserves at least enough space for inCount more elements
    declare function PreAllocate(inCount as uinteger) as uinteger
    
    'Deletes an item from the array and re-densifies (swap and pop)
    'Returns the index of the item that was moved into its place
    declare function Remove(index as uinteger) as integer
    
    declare sub Resize(newSize as uinteger)
    declare sub ResizeNoSave(newSize as uinteger)
    declare sub MoveItem(fromIndex as uinteger, toIndex as uinteger)
    declare sub SwapItems(indexA as uinteger, indexB as uinteger)
    
    declare function GetArrayPointer() as any ptr
    
    'Changes ownership of resources from one dynamic array to another
    declare static sub Move(byref leftSide as DynamicArrayType, byref rightSide as DynamicArrayType)
    
    declare function GetUsedMemorySize() as uinteger
    
    declare constructor(inElementSize as uinteger)
    declare constructor(inElementSize as uinteger, initialArraySize as uinteger)
    declare destructor()
    
    declare operator [] (index as uinteger) ByRef as ubyte
    
    declare operator Let (byref rightSide as DynamicArrayType)
    
end type

#endif
