#ifndef QueryIterator_bas
#define QueryIterator_bas

#include once "FBECS.bi"

namespace FBECS

operator QueryTermType.Let ( _
        byref rightSide as QueryTermType)
    this.ComponentID = rightSide.ComponentID
    this.Op = rightSide.Op
end operator

static function _QuerySortIndexPositionTupleType.Compare cdecl ( _
        byval inTupleA as const any ptr, _
        byval inTupleB as const any ptr) as long
    
    dim a as _QuerySortIndexPositionTupleType ptr = _
        cast(_QuerySortIndexPositionTupleType ptr, inTupleA)
    dim b as _QuerySortIndexPositionTupleType ptr = _
        cast(_QuerySortIndexPositionTupleType ptr, inTupleB)
    
    return (a->SortIndex < b->SortIndex) OR ((a->SortIndex > b->SortIndex) AND 1)

end function

constructor QueryType()
end constructor

constructor QueryType(byref inName as string)
    this.Name = inName
end constructor

destructor QueryType()
	'Everything can be default destructed
	'Including the NodeMap as the value
	'is just a pointer
	this.Terminate()
end destructor

function QueryType.AddComponent overload ( _
        byref inTerm as QueryTermType) byref as QueryType

    if this.ComponentList.AddComponent(inTerm.ComponentID) then
        'Only add the component to the unsorted list if the
        'component was not a duplicate
        this.UnsortedComponents.PushUDT(@inTerm.ComponentID)
        this.QueryOperators.PushUDT(@inTerm.Op)
    end if
    
    this.PreparedFlag = 0
    
    return this
    
end function

function QueryType.AddComponent overload ( _
        inComponent as ComponentIDType) byref as QueryType
    
    'Use default _AND clause
    dim tempQueryTerm as QueryTermType = (inComponent)
    
    return this.AddComponent(tempQueryTerm)
    
end function

function QueryType.AddComponents( _
        inComponents() as QueryTermType) byref as QueryType

    for i as integer = 0 to ubound(inComponents)
        this.AddComponent(inComponents(i))
    next

    return this

end function

function QueryType.GetPairFromBase( _
        inBaseID as ComponentIDType) as PairComponentContainerType

    dim retID as PairComponentContainerType = (0, 0)
    dim pairID as PairComponentContainerType ptr
    
    if this.ActiveArchetype = 0 then
        LogWarn("No active archetype")
        return retID
    end if
    
    pairID = this.ActiveArchetype->BaseToPairDictionary.KeyExistsGet(inBaseID)
    if pairID = 0 then
        return retID
    end if
    
    return *pairID
    
end function

function QueryType.GetArgumentArray( _
        componentQueryIndex as integer) as any ptr

    dim tempList as DynamicArrayType ptr ptr
    dim componentIDArray as ComponentIDType ptr = this.UnsortedComponents.GetArrayPointer()
    
    if componentQueryIndex < 0 ORELSE componentQueryIndex >= this.UnsortedComponents.Count then
        LogError( _
            !"Query argument out of range.\n"; _
            "Query name: ";this.Name;!"\n"; _
            "Range: (0 - ";this.UnsortedComponents.Count-1;") requested: ";componentQueryIndex)
    end if
    
    tempList = this.NodeMap.KeyExistsGet(componentIDArray[componentQueryIndex])
    if tempList = 0 then
        LogError( _
            !"Did not find component in query.\n"; _
            "Query name: ";this.Name;!"\n";_
            "Offending component: ";componentIDArray[componentQueryIndex].ToString();!"\n"; _
            "Component list :";this.ComponentList.ToString())
    end if
    
    return (*tempList)->GetArrayPointer()

end function

function QueryType.GetComponentArray( _
        inComponentID as ComponentIDType) as any ptr

    dim componentIndex as ushort ptr

    if this.ActiveArchetype = 0 then
        return 0
    end if
    
    componentIndex = this.ActiveArchetype->ComponentIDDictionary.KeyExistsGet(inComponentID)
    if componentIndex = 0 then
        return 0
    end if
    
    return this.ActiveArchetype->ComponentList[*componentIndex]->GetArrayPointer()
    
end function

function QueryType.HasComponent( _
        inComponentID as ComponentIDType) as integer

    if this.ActiveArchetype = 0 then
        return 0
    end if
    
    if this.ActiveArchetype->ComponentIDDictionary.KeyExists(inComponentID) = 0 then
        return 0
    end if

    return 1

end function

function QueryType.HasBaseComponent( _
        inBaseID as ComponentIDType) as integer
    
    if this.ActiveArchetype = 0 then
        return 0
    end if
    
    if this.ActiveArchetype->BaseToPairDictionary.KeyExists(inBaseID) = 0 then
        return 0
    end if

    return 1
    
end function

function QueryType.GetEntity( _
        index as integer) as EntityIDType

    dim retID as EntityIDType

    if this.ActiveArchetype = 0 ORELSE _
       this.ActiveEntities.Count = 0 then
        'Return default null ID
        return retID
    end if
    
    retID = *DYNAMIC_ARRAY_CAST(EntityIDType ptr, this.ActiveEntities, index)
    
    return retID

end function

function QueryType.IsFinished() as integer
	return this.ArchetypeIndex >= this.ArchetypeIDs.Count
end function

sub QueryType.Terminate()

	if this.ActiveArchetype then
        this.ActiveArchetype->LockedFlag -= 1
    end if
	
	this.PreparedFlag = 0
    this.ActiveArchetype = 0

end sub

function QueryType.CheckValidity() as integer
    
    dim ANDCount as integer = 0
    dim NOTCount as integer = 0
    dim SORTONCount as integer = 0
    dim ElseCount as integer = 0
    
    dim op as QueryOperatorEnum
    
    dim retVal as integer = 1
    
    for i as integer = 0 to this.QueryOperators.Count-1
        
        op = *DYNAMIC_ARRAY_CAST(QueryOperatorEnum ptr, this.QueryOperators, i)
        
        select case as const op
            case _NULL
                'NULL defaults to AND
                'This keeps the API simpler to use
                ANDCount += 1
            case _AND
                ANDCount += 1
            case _ANDNOT
                NOTCount += 1
            case _SORTON_FORWARD
                SORTONCount += 1
            case _SORTON_BACKWARD
                SORTONCount += 1
            case else
                LogWarn("Query validation: invalid operation encountered: ";op)
                ElseCount += 1
        end select
        
    next
    
    if ANDCount = 0 then
        LogWarn( _
            !"Query failed validation: at least one AND clause is required.\n"; _
            "Query name: ";this.Name;!"\n" _
            "Query terms: ";this.ComponentList.ToString())
        
        retVal = 0
    end if
    
    if SORTONCount > 1 then
        LogWarn( _
            !"Query failed validation: only up to 1 SORTON clause is allowed.\n"; _
            "SORTON clauses found: ";SORTONCount;!"\n"; _
            "Query name: ";this.Name;!"\n" _
            "Query terms: ";this.ComponentList.ToString())
        
        retVal = 0
    end if
    
    if ElseCount > 0 then
        LogWarn("Invalid operations in query: ";this.Name)
        retVal = 0
    end if
    
    return retVal

end function

operator QueryType.Let( _
        byref rightSide as QueryType)
    
    this.Name = rightSide.Name
    this.ArchetypeIndex = rightSide.ArchetypeIndex
    this.ArchetypeIDs = rightSide.ArchetypeIDs
    this.ComponentList = rightSide.ComponentList
    this.UnsortedComponents = rightSide.UnsortedComponents
    this.QueryOperators = rightSide.QueryOperators
	'Do not copy meta data
	this.CachedInfo = rightSide.CachedInfo
    
end operator

end namespace

#endif
