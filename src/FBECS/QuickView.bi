#ifndef QuickView_bi
#define QuickView_bi

#include once "../utilities/DynamicArray.bi"
#include once "Entity.bi"
#include once "Component.bi"
#include once "Archetype.bi"

namespace FBECS

'A parred down version of a query, supports 
'only one component, but builds much quicker
'See QueryType for documentation, it's basically the same
type QuickViewType
    
    dim as uinteger<32> ArchetypeIndex
    
    dim as DynamicArrayType ArchetypeIDs = DynamicArrayType(sizeof(ArchetypeIDType))
    
    dim as ArchetypeType ptr ActiveArchetype
    
    'A copy of the entities from the active achetype
    dim as DynamicArrayType ActiveEntities = DynamicArrayType(sizeof(EntityIDType))
    
    dim as ComponentIDType QueriedComponent
    
    dim as integer NodeCount
    
    dim PreparedFlag as ubyte
	
	dim MetaData as QueryType.MetaDataType
    
    declare constructor()
    declare constructor( _
        inComponentID as ComponentIDType)
    
    declare function GetPairFromBase( _
        inBaseID as ComponentIDType) as PairComponentContainerType
    
    'Returns the component data array
    declare function GetArgumentArray() as any ptr
    
    'Get arbitrary components from an archetype
    declare function GetComponentArray( _
        inComponentID as ComponentIDType) as any ptr
    
    declare function HasComponent( _
        inComponentID as ComponentIDType) as integer
    
    declare function HasBaseComponent( _
        inBaseID as ComponentIDType) as integer
    
    'Get the entity indexed at our iteration index
    declare function GetEntity( _
        index as integer) as EntityIDType

    'Returns non-0 if the quick view has been fully iterated over
    '0 otherwise
    declare function IsFinished() as integer

    'Cleans up a quick view after iterating
    'This is not a destructor
    declare sub Terminate()
    
    'NOTE: Let only copies values set initially, not ones updated every
    'time the query is called.
    'Copied values:
    '    - ArchetypeIndex, ArchetypeIDs, QueriedComponent
    'NOT copied values:
    '    - NodeCount, PreparedFlag
    declare operator Let( _
        byref rightSide as QuickViewType)
    
end type

end namespace

#endif
