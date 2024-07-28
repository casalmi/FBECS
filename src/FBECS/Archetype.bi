#ifndef Archetype_bi
#define Archetype_bi

#include once "../utilities/Dictionary.bi"
#include once "Entity.bi"
#include once "Component.bi"

namespace FBECS

type ArchetypeIDType as uinteger<32>

'Function used to sort by archetype IDs
declare function ArchetypeIDType_Compare cdecl ( _
        byval inA as const any ptr, _
        byval inB as const any ptr) as long

'Map component add/remove to next archetype
'TODO: Merge this into the archetype Type
type ArchetypeMapEdgeType
    
    dim as ArchetypeIDType AddReference
    dim as ArchetypeIDType RemoveReference

    declare operator Let ( _
        byref rightSide as ArchetypeMapEdgeType)
    
end type

'Pair to precisely map baseID -> pairID
'The TargetID could have info outside its 32 bit base value like generation.
'We store that un-truncated value here.
type PairComponentContainerType
	'The exact target ID used at creation of the pair, generation and all
    dim as EntityIDType TargetID
	'The pair component itself
    dim as ComponentIDType PairID
    
    declare operator Let ( _
        byref rightSide as PairComponentContainerType)
    
end type

DEFINE_DICTIONARY_TYPE(ComponentIDType, ArchetypeMapEdgeType, DictionaryType_CompIDArchMapEdge)
DEFINE_DICTIONARY_TYPE(ComponentIDType, PairComponentContainerType, DictionaryType_CompIDPairContainer)

'Ah yes my lovely naming schemeScheme
type ArchetypeType

    'ID to uniquely identify the archetype amongst other archetypes
    dim as ArchetypeIDType ID
    
    'Boolean denoting whether or not this archetype is in active use
    dim as integer<32> LockedFlag
        
    'Map the component IDs to the component array index
    dim as DictionaryType_CompIDUShort ComponentIDDictionary
    
    'Map the base component ID to its (base, target) component
    dim as DictionaryType_CompIDPairContainer BaseToPairDictionary
    
    'List of component IDs unique to this archetype
    dim as ComponentIDListType ComponentIDList
    
    'Array of component data arrays
    dim as uinteger<32> ComponentListCount
    dim as DynamicArrayType ptr ptr ComponentList

    'Array of entities at each column
    'Allows for re-densifying arrays on entity move
    'Consider working around this somehow, it may not be necessary
    'if I were to use something like a sparse array
    dim as DynamicArrayType EntityList = DynamicArrayType(sizeof(EntityIDType))
    
    'Map of component ID + add/remove to the next archetype in the archetype graph
    'Allows for quickly getting the next archetype given a componentID + add/remove
    dim as DictionaryType_CompIDArchMapEdge EdgeDictionary

    declare constructor()
    
    declare constructor( _
        inID as ArchetypeIDType, _ 
        byref inComponentList as ComponentIDListType, _
        inComponentSizes() as uinteger<32>)
    
    declare destructor()
    
    declare sub SetAddMapping( _
        inComponentID as ComponentIDType, _
        inArchetype as ArchetypeIDType)
    
    declare sub SetRemoveMapping( _
        inComponentID as ComponentIDType, _
        inArchetype as ArchetypeIDType)
    
    declare function ToString() as string
    
end type

'''''''''''''''''''''''''''ENTITY LOCATION'''''''''''''''''''''''''''

type EntityLocationSpecifierType
    
    dim as ArchetypeType ptr Archetype
    dim as uinteger<32> Index
    
    declare constructor()
    declare constructor( _
        inArchetype as ArchetypeType ptr, _
        inIndex as uinteger<32>)
    
    declare function ToString() as string
    
    declare operator Let ( _
        byref rightSide as EntityLocationSpecifierType)
    
end type

end namespace

#endif
