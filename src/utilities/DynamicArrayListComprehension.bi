#ifndef DynamicArrayListComprehension_bi
#define DynamicArrayListComprehension_bi

'Use this to get the iterator in a FOR_IN loop
'This is not wrapped in parenthesis
#define FOR_IN_ITER _for_in_iter

#macro FOR_IN(_VARIABLE, _TYPE, _LIST)
scope
'Use this to enforce type defining
#if typeof(_LIST) <> typeof(DynamicArrayType)
#error Type mismatch, at parameter 2 ##_LIST: expected DynamicArrayType
#endif
dim byref _listRef as DynamicArrayType = _LIST
for FOR_IN_ITER as integer = 0 to _listRef.Count-1
    dim byref _VARIABLE as ##_TYPE = _
        *DYNAMIC_ARRAY_CAST(typeof(##_TYPE) ptr, _listRef, _for_in_iter)
#endmacro

'The same FOR_IN, but iterates in reverse
#macro FOR_IN_REV(_VARIABLE, _TYPE, _LIST)
scope
'Use this to enforce type defining
#if typeof(_LIST) <> typeof(DynamicArrayType)
#error Type mismatch, at parameter 2 ##_LIST: expected DynamicArrayType
#endif
dim byref _listRef as DynamicArrayType = _LIST
for FOR_IN_ITER as integer = _listRef.Count-1 to 0 step -1
    dim byref _VARIABLE as ##_TYPE = _
        *DYNAMIC_ARRAY_CAST(typeof(##_TYPE) ptr, _listRef, _for_in_iter)
#endmacro

#macro FOR_IN_NEXT
next
end scope
#endmacro

#macro FOR_IN_IF(_VARIABLE, _TYPE, _LIST, _STATEMENT)
scope
'Use this to enforce type defining
#if typeof(_LIST) <> typeof(DynamicArrayType)
#error Type mismatch, at parameter 2 ##_LIST: expected DynamicArrayType
#endif
dim byref _listRef as DynamicArrayType = _LIST
for FOR_IN_ITER as integer = 0 to _listRef.Count-1
    dim byref _VARIABLE as ##_TYPE = _
        *DYNAMIC_ARRAY_CAST(typeof(##_TYPE) ptr, _listRef, _for_in_iter)
    
    if NOT (_STATEMENT) then
        continue for
    end if
#endmacro

#macro FOR_IN_IF_NEXT
next
end scope
#endmacro

#macro FOR_IN_CONTINUE
:continue for:
#endmacro

#macro FOR_IN_EXIT
:exit for:
#endmacro

#endif
