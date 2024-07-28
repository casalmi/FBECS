#ifndef QuickView_bas
#define QuickView_bas

#include once "FBECS.bi"

namespace FBECS

constructor QuickViewType()
    
    this.ArchetypeIndex = 0
    this.ActiveArchetype = 0
    this.QueriedComponent.ID = 0
    this.NodeCount = 0
    this.PreparedFlag = 0
    
end constructor

constructor QuickViewType( _
        inComponentID as ComponentIDType)

    this.Constructor()
    this.QueriedComponent = inComponentID

end constructor

function QuickViewType.GetPairFromBase( _
        inBaseID as ComponentIDType) as PairComponentContainerType

    dim retID as PairComponentContainerType
    dim pairID as PairComponentContainerType ptr
    
    if this.ActiveArchetype = 0 then
        return retID
    end if
    
    pairID = this.ActiveArchetype->BaseToPairDictionary.KeyExistsGet(inBaseID)
    if pairID = 0 then
        return retID
    end if
    
    return *pairID
    
end function

function QuickViewType.GetArgumentArray() as any ptr
    
    dim componentIndex as ushort ptr

    if this.ActiveArchetype = 0 then
        return 0
    end if
    
    componentIndex = this.ActiveArchetype->ComponentIDDictionary.KeyExistsGet( _
        this.QueriedComponent)
    if componentIndex = 0 then
        return 0
    end if
    
    return this.ActiveArchetype->ComponentList[*componentIndex]->GetArrayPointer()
    
end function

function QuickViewType.GetComponentArray( _
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

function QuickViewType.HasComponent( _
        inComponentID as ComponentIDType) as integer

    dim componentIndex as ushort ptr

    if this.ActiveArchetype = 0 then
        return 0
    end if
    
    if this.ActiveArchetype->ComponentIDDictionary.KeyExists(inComponentID) = 0 then
        return 0
    end if

    return 1

end function

function QuickViewType.HasBaseComponent( _
        inBaseID as ComponentIDType) as integer
    
    if this.ActiveArchetype = 0 then
        return 0
    end if
    
    if this.ActiveArchetype->BaseToPairDictionary.KeyExists(inBaseID) = 0 then
        return 0
    end if

    return 1
    
end function

function QuickViewType.GetEntity( _
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

function QuickViewType.IsFinished() as integer
    return this.ArchetypeIndex >= this.ArchetypeIDs.Count
end function

sub QuickViewType.Terminate()
	
    if this.ActiveArchetype then
        this.ActiveArchetype->LockedFlag -= 1
	end if
		
	this.PreparedFlag = 0
    this.ActiveArchetype = 0

end sub

operator QuickViewType.Let( _
        byref rightSide as QuickViewType)

    _Log("quick view assignment operator")

    this.ArchetypeIndex = rightSide.ArchetypeIndex
    this.ArchetypeIDs = rightSide.ArchetypeIDs
    this.QueriedComponent = rightSide.QueriedComponent
    
end operator

end namespace

#endif
