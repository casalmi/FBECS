#ifndef Component_bi
#define Component_bi

#include once "../utilities/Dictionary.bi"
#include once "../utilities/DynamicArray.bi"
#include once "Entity.bi"

namespace FBECS

type ComponentIDType as EntityIDType

type ComponentDescriptorType
    
    'Holds descriptive meta-data for a component
    
    enum ComponentFlag
        IS_PAIR = 1
    end enum
    
    'The entity ID to the component
    dim as ComponentIDType ID
    
    'Size of the corresponding data type in bytes
    dim as uinteger<32> Size
    
    'Human readable name
    dim as string Name
    
    'Constructor/destructor/move hooks
    dim Ctor as sub(as any ptr)
    dim Dtor as sub(as any ptr)
    dim Copy as sub(as any ptr, as any ptr)
    dim Move as sub(as any ptr, as any ptr)
    
    'Flags for what kind of component it is
    union
        dim as ubyte _Flags
        type
            IsPair : 1 as ubyte
            IsBase : 1 as ubyte
        end type
    end union
    
    dim as ComponentIDType BaseID
    dim as EntityIDType TargetID
    
    'Sort index for ensuring certain components are queried in a certain order
    dim as integer<32> SortIndex
    
    declare constructor()
    
    declare constructor( _
        inID as ComponentIDType, _
        inSize as uinteger<32>, _
        inName as string, _
        inCtor as sub(as any ptr) = 0, _
        inDtor as sub(as any ptr) = 0, _
        inCopy as sub(as any ptr, as any ptr) = 0, _
        inMove as sub(as any ptr, as any ptr) = 0, _
        inFlags as ubyte = 0, _
        inSortIndex as integer<32> = 0)
    
    declare destructor()
    
    declare function ToString() as string
    
    declare operator Let ( _
        byref rightSide as ComponentDescriptorType)
    
end type

'''''''''''''COMPONENT ID LIST TYPE'''''''''''''

'A sorted list of unique component IDs
'Maintains its own sorting
type ComponentIDListType
    
    dim as DynamicArrayType ComponentIDs = DynamicArrayType(sizeof(ComponentIDType))
    
    declare constructor()
    declare constructor( _
        inComponents() as ComponentIDType)
    
    declare destructor()
    
    'Append a component to the list and re-sort
    'Returns <> 0 if component was added
    'and returns 0 if component was already in the list (duplicate)
    declare function AddComponent( _
        inComponentID as ComponentIDType) as integer
    
    'Remove a component to the list and re-densify
    'Returns <> 0 if the component was removed
    'and 0 if the component was not in the list
    declare function RemoveComponent( _
        inComponentID as ComponentIDType) as integer
    
    declare function HasDup() as integer
    
    declare function ToString() as string
    
    'Property that returns the count of IDs
    'For convenience.
    declare property Count() as integer
    
    declare operator [] (byref index as integer) byref as ComponentIDType
    
    declare operator Let ( _
        byref rightSide as ComponentIDListType)

end type

'Hash function for the dictionary
declare function _GetHash32 overload (byref inVal as ComponentIDListType) as uinteger<32>

DEFINE_DICTIONARY_TYPE(ComponentIDType, ushort, DictionaryType_CompIDUShort)

declare operator = overload ( _
    byref leftSide as ComponentIDListType, _
    byref rightSide as ComponentIDListType) as integer

end namespace

#endif