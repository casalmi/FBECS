#ifndef Archetype_bas
#define Archetype_bas

#include "FBECS.bi"

namespace FBECS

GENERATE_DICTIONARY_TYPE(ComponentIDType, ArchetypeMapEdgeType, DictionaryType_CompIDArchMapEdge)
GENERATE_DICTIONARY_TYPE(ComponentIDType, PairComponentContainerType, DictionaryType_CompIDPairContainer)

'Function used to sort by archetype IDs
function ArchetypeIDType_Compare cdecl ( _
        byval inA as const any ptr, _
        byval inB as const any ptr) as long

    dim a as ArchetypeIDType ptr = cast(ArchetypeIDType ptr, inA)
    dim b as ArchetypeIDType ptr = cast(ArchetypeIDType ptr, inB)

    return (*a < *b) OR ((*a > *b) AND 1)

end function

operator ArchetypeMapEdgeType.Let( _
        byref rightSide as ArchetypeMapEdgeType)
    
    this.AddReference = rightSide.AddReference
    this.RemoveReference = rightSide.RemoveReference

end operator

operator PairComponentContainerType.Let( _
        byref rightSide as PairComponentContainerType)
    this.TargetID = rightSide.TargetID
    this.PairID = rightSide.PairID
end operator

constructor EntityLocationSpecifierType()
    this.Archetype = 0
    this.Index = -1
end constructor

constructor EntityLocationSpecifierType( _
        inArchetype as ArchetypeType ptr, _
        inIndex as uinteger<32>)

    this.Archetype = inArchetype
    this.Index = inIndex

end constructor

function EntityLocationSpecifierType.ToString() as string
    
    dim retString as string = ""
    
    retString = retString & "{" & this.Archetype->ID & ","
    retString = retString & this.Index & "}"
    
    return retString
    
end function

operator EntityLocationSpecifierType.Let ( _
        byref rightSide as EntityLocationSpecifierType)

    this.Archetype = rightSide.Archetype
    this.Index = rightSide.Index

end operator

'''''''''''''''''''''''''''END '''''''''''''''''''''''''''

constructor ArchetypeType()

    this.ID = -1
    this.ComponentList = 0
    
end constructor

constructor ArchetypeType( _
        inID as ArchetypeIDType, _
        byref inComponentList as ComponentIDListType, _
        inComponentSizes() as uinteger<32>)
    
    this.ID = inID
    
    if inComponentList.Count = 0 then
        return
    end if
    
    'Copy the list
    this.ComponentIDList = inComponentList
    
	'TODO: Optimize
	'Convert the ComponentList from array of pointers 
	'into a direct array of DynamicArrayType.
	'Use allocate + placement new + deallocate.
	'Will need to change anything reliant on this setup
	
    'Create as many component arrays as we received in the component list
    this.ComponentList = _ 
        new DynamicArrayType ptr[inComponentList.Count]
	
	this.ComponentListCount = inComponentList.Count
	
    for i as integer = 0 to inComponentList.Count - 1
		
		this.ComponentList[i] = new DynamicArrayType(inComponentSizes(i), 1)
        
        'Set the componentID to map to the index of the component in the archetype
        this.ComponentIDDictionary[inComponentList[i]] = i

    next
    
end constructor

destructor ArchetypeType()
    
    this.ID = -1
    
    if this.ComponentList then
        for i as integer = 0 to this.ComponentListCount - 1
			delete(this.ComponentList[i])
            this.ComponentList[i] = 0
        next
        
		delete [] this.ComponentList
        this.ComponentList = 0
    end if

end destructor

sub ArchetypeType.SetAddMapping( _
        inComponentID as ComponentIDType, _
        inArchetype as ArchetypeIDType)

    this.EdgeDictionary[inComponentID].AddReference = inArchetype

end sub

sub ArchetypeType.SetRemoveMapping( _
        inComponentID as ComponentIDType, _
        inArchetype as ArchetypeIDType)

    this.EdgeDictionary[inComponentID].RemoveReference = inArchetype

end sub

function ArchetypeType.ToString() as string

    dim retString as string = ""
    
    retString = retString & "{id: " & this.ID & ", components: {"
    
    dim as ComponentIDType tempCompID = any

    for i as integer = 0 to this.ComponentIDList.Count-1

        retString = retString & this.ComponentIDList[i].ToString()

        if i < this.ComponentIDList.Count-1 then
             retString = retString & ", " 
        end if

    next
    
    retString = retString & "}}"
    
    return retString
    
end function

end namespace

#endif
