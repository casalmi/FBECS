#ifndef QueryIterator_bi
#define QueryIterator_bi

#include once "../utilities/Dictionary.bi"
#include once "../utilities/DynamicArray.bi"
#include once "Entity.bi"
#include once "Component.bi"
#include once "Archetype.bi"

namespace FBECS

DEFINE_DICTIONARY_TYPE(ComponentIDType, DynamicArrayType ptr, DictionaryType_CompIDDynamicArray)

enum QueryOperatorEnum
	'Sentinel type, do not use
    _NULL            = 0
	'Query on entities with this component
	'(default, unnecessary to specify)
    _AND             = 1 SHL 0
	'Query on entities that do NOT have this component
    _ANDNOT          = 1 SHL 1
	'Sort ascending on the sort value specified by the component
    _SORTON_FORWARD  = 1 SHL 2
	'Sort descending on the sort value specified by the component
    _SORTON_BACKWARD = 1 SHL 3
end enum

type QueryTermType
    
    'DO NOT CHANGE ORDER OF DATA MEMBERS
    dim as ComponentIDType ComponentID
    dim as QueryOperatorEnum Op
    
    'DO NOT ADD CONSTRUCTORS
    'This type relies on the implicit constructor
    'to make our lives easier in the API
    /'
    declare constructor()
    declare constructor( _
        inComponentID as ComponentIDType, _
        inOperator as QueryOperatorEnum = QueryOperatorEnum._AND)
    '/
    declare operator Let ( _
        byref rightSide as QueryTermType)
    
end type

'This is used as a container to allow for using qsort
'when sorting archetypes by component sort index
type _QuerySortIndexPositionTupleType
    dim Position as uinteger<32>
    dim SortIndex as integer<32>
    
    declare static function Compare cdecl ( _
        byval inIDA as const any ptr, _
        byval inIDB as const any ptr) as long
    
end type

type QueryType
    
	type MetaDataType
		dim as integer<32> EntityCount
		dim as integer<32> ArchetypeCount
		dim as double PrepareTime
	end type
	
	type CachedInfoType
		'Determines whether this query is cached or not
		dim as ubyte IsCached
		'0 if the query needs updating, 1 if the existing
		'query data is sufficient
		dim as ubyte UseExistingData
	end type
	
    'Human readable name to identify the query
    dim as string Name
    
    'The current archetype index gets updated every call to QueryNext
    dim as uinteger<32> ArchetypeIndex
    
    'Archetype ID keeps track of archetypes that match our query
    dim as DynamicArrayType ArchetypeIDs = DynamicArrayType(sizeof(ArchetypeIDType))
    
    'Pointer to the current archetype
    dim as ArchetypeType ptr ActiveArchetype
    
    'A copy of the entities from the active achetype
    dim as DynamicArrayType ActiveEntities = DynamicArrayType(sizeof(EntityIDType))
    
    'List of components we're querying on
    dim as ComponentIDListType ComponentList
    'The same list, but unsorted...
    'TODO: Replace the sorted list with this one
    dim as DynamicArrayType UnsortedComponents = DynamicArrayType(sizeof(ComponentIDType))
    
    'List of operators for a query
    dim as DynamicArrayType QueryOperators = DynamicArrayType(sizeof(QueryOperatorEnum))
    
    'Count of components in this node
    dim as integer NodeCount
	
    'Map of component ID to component array ptr, updated every call to QueryNext
    dim as DictionaryType_CompIDDynamicArray NodeMap
    
    'Mark whether or not this query has been properly prepared
    dim PreparedFlag as ubyte
	
	'Some meta data about the query itself filled in when it's prepared
	dim MetaData as MetaDataType
	
	'Some data about cached status
	dim CachedInfo as CachedInfoType
    
    declare constructor()
    declare constructor( _
        byref inName as string)
    
	declare destructor()
	
    declare function AddComponent overload ( _
        byref inTerm as QueryTermType) byref as QueryType
    
    declare function AddComponent overload ( _
        inComponent as ComponentIDType) byref as QueryType
 
    declare function AddComponents( _
        inComponents() as QueryTermType) byref as QueryType
    
    'Get the pair component given a base from the active archetype
    declare function GetPairFromBase( _
        inBaseID as ComponentIDType) as PairComponentContainerType
    
    'The componentQueryIndex is the index of the component in the order it was
    'added.  For example: I add "comp1" and then "comp2" to a query, then to
    'get the array for "comp1", I pass 0 for the componentQueryIndex. 
    'Likewise, I pass 1 for "comp2"
    'This should be used over GetComponentArray for performance
    declare function GetArgumentArray( _
        componentQueryIndex as integer) as any ptr
    
    'Get arbitrary components from an archetype
    declare function GetComponentArray( _
        inComponentID as ComponentIDType) as any ptr
    
    'Returns whether or not a component exists in the active archetype
    declare function HasComponent( _
        inComponentID as ComponentIDType) as integer
    
    'Returns whether or not the archetype has pair components with the base
    declare function HasBaseComponent( _
        inBaseID as ComponentIDType) as integer
    
    'Get the entity indexed at our iteration index
    declare function GetEntity( _
        index as integer) as EntityIDType

    'Returns non-0 if the query has been fully iterated over
    '0 otherwise
    declare function IsFinished() as integer

    'Cleans up a query after it's done being used
    'This is not a destructor
    declare sub Terminate()
    
    'Returns 1 if the query is valid, 0 if invalid
    'Will throw warnings on invalid query state
    declare function CheckValidity() as integer
    
    'NOTE: Let only copies values set initially, not ones updated every
    'time the query is called.
    'Copied values:
    '    - ArchetypeIndex, ArchetypeIDs, ComponentList, UnsortedComponents
    'NOT copied values:
    '    - NodeCount, NodeMap, PreparedFlag
    declare operator Let( _
        byref rightSide as QueryType)
    
end type

end namespace

#endif
