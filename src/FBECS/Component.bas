#ifndef Component_bas
#define Component_bas

#include once "crt/stdlib.bi"

#include once "FBECS.bi"

namespace FBECS

function _GetHash32 overload (byref inVal as ComponentIDListType) as uinteger<32>

    if inVal.Count = 0 then
        dim tempZero as uinteger<32> = 0
        return FNV1a_32(@tempZero, sizeof(tempZero))
    end if

    return FNV1a_32(@inVal[0], sizeof(ComponentIDType) * inVal.Count)

end function

GENERATE_DICTIONARY_TYPE(ComponentIDType, ushort, DictionaryType_CompIDUShort)

'Equivalent operator for the dictionary
operator = overload ( _
    byref leftSide as ComponentIDListType, _
    byref rightSide as ComponentIDListType) as integer

    if leftSide.Count <> rightSide.Count then
        return 0
    end if
    
    if leftSide.Count = 0 then
        return -1
    end if
    
    for i as integer = 0 to leftSide.Count-1
        if leftSide[i] <> rightSide[i] then
            return 0
        end if
    next
    
    return -1
    
end operator

constructor ComponentIDListType()
end constructor

constructor ComponentIDListType( _
        inComponents() as ComponentIDType)

    dim needsSortFlag as ubyte = 0

    this.Constructor()

    this.ComponentIDs.ResizeNoSave(ubound(inComponents)+1)
    
    this.ComponentIDs.Count = ubound(inComponents)+1
    
    if this.ComponentIDs.Count = 0 then
        return
    end if
    
    this[0] = inComponents(0)
    
    for i as integer = 1 to ubound(inComponents)
        this[i] = inComponents(i)
        needsSortFlag OR= this[i-1] > this[i]
    next
    
    if needsSortFlag then
        qsort(@this[0], this.Count, sizeof(ComponentIDType), @EntityIDType.Compare)
    end if
    
end constructor

destructor ComponentIDListType()
end destructor

function ComponentIDListType.AddComponent( _
        inComponentID as ComponentIDType) as integer

    'In place insertion sort here
    dim i as integer = 0
    dim tempID1 as ComponentIDType
    dim tempID2 as ComponentIDType
    
    for i = 0 to this.Count-1
        if this[i] >= inComponentID then
            exit for
        end if
    next
    
    if (this.Count > 0) ANDALSO (i < this.Count) ANDALSO _
       (this[i] = inComponentID) then
        'Duplicate
        return 0
    end if
	
    'Insert and keep sorted
    this.ComponentIDs.PushUDT(@inComponentID)
    
    'Insert our new item at its correct location first
    tempID1 = this[this.Count-1]
    
    for i = i to this.Count-1
        'Move each item up the list
        tempID2 = this[i]
        this[i] = tempID1
        tempID1 = tempID2
    next
    
    return 1
    
end function

function ComponentIDListType.RemoveComponent( _
        inComponentID as ComponentIDType) as integer
    
    dim i as integer = 0
    dim tempID1 as ComponentIDType
    dim tempID2 as ComponentIDType
    
    for i = 0 to this.Count-1
        if this[i] = inComponentID then
            exit for
        end if
    next

    if i >= this.Count then
        'Wasn't in the list
        return 0
    end if

    'Remove the item and keep sorted
    'ComponentIDs.Remove will move the item from the back of the list
    'to the spot at index.  Just bubble the item back up
    this.ComponentIDs.Remove(i)

    for i = i to this.Count-2
        'Move each item up the list
        tempID1 = this[i+1]
        this[i+1] = this[i]
        this[i] = tempID1
    next
    
    return 1
    
end function

function ComponentIDListType.HasDup() as integer
    
    if this.Count <= 1 then
        return 0
    end if
    
    for i as integer = 1 to this.Count-1
        if this[i] = this[i-1] then
            return 1
        end if
    next
    
    return 0
    
end function

function ComponentIDListType.ToString() as string
    
    dim retString as string = ""
    
    retString = retString & "{"
    
    for i as integer = 0 to this.Count-1
    
        retString = retString & this[i].ToString()
        if i < this.Count-1 then
            retString = retString & ", "
        end if
    
    next

    retString = retString & "}"
    
    return retString
    
end function

property ComponentIDListType.Count() as integer
    return this.ComponentIDs.Count
end property

operator ComponentIDListType.[] ( _
        byref index as integer) byref as ComponentIDType
    
    return *DYNAMIC_ARRAY_CAST(ComponentIDType ptr, this.ComponentIDs, index)

end operator

operator ComponentIDListType.Let ( _
        byref rightSide as ComponentIDListType)
    
    'redim this.ComponentIDs(ubound(rightSide.ComponentIDs))
    this.ComponentIDs.ResizeNoSave(rightSide.Count)
    
    this.ComponentIDs.Count = rightSide.Count

    if rightSide.Count = 0 then
        return
    end if
    
    'Copy the other component list
    memcpy(@this[0], @rightSide[0], sizeof(ComponentIDType) * rightSide.Count)

end operator

'''''''''''''END COMPONENT LIST ID TYPE'''''''''''''

constructor ComponentDescriptorType()
    
end constructor

constructor ComponentDescriptorType( _
        inID as ComponentIDType, _
        inSize as uinteger<32>, _
        inName as string, _
        inCtor as sub(as any ptr) = 0, _
        inDtor as sub(as any ptr) = 0, _
        inCopy as sub(as any ptr, as any ptr) = 0, _
        inMove as sub(as any ptr, as any ptr) = 0, _
        inFlags as ubyte = 0, _
        inSortIndex as integer<32> = 0)

    this.ID = inID
    this.Size = inSize
    this.Name = inName
    this.Ctor = inCtor
    this.Dtor = inDtor
    this.Copy = inCopy
    this.Move = inMove
    this._Flags = inFlags
    this.SortIndex = inSortIndex
    this.BaseID.ID = 0
    this.TargetID.ID = 0
    
end constructor

destructor ComponentDescriptorType()
    this.ID = -1
    this.Size = 0
    this.Name = ""
    this.Ctor = 0
    this.Dtor = 0
    this.Copy = 0
    this.Move = 0
    this._Flags = 0
    this.SortIndex = 0
    this.BaseID.ID = 0
    this.TargetID.ID = 0
end destructor

function ComponentDescriptorType.ToString() as string
    
    dim retString as string = ""
    
    retString = retString & "{" & _
        "id: " & cast(uinteger<64>, this.ID) & ", " & _
        "size: " & this.Size & ", " & _
        "name: "
    
    if len(this.Name) > 0 then
        retString = retString & this.Name
    else
        retString = retString & !"\"\""
    end if

    retString = retString & "}"

    return retString

end function

operator ComponentDescriptorType.Let ( _
        byref rightSide as ComponentDescriptorType)
        
    this.ID = rightSide.ID
    this.Size = rightSide.Size
    this.Name = rightSide.Name
    this.Ctor = rightSide.Ctor
    this.Dtor = rightSide.Dtor
    this.Copy = rightSide.Copy
    this.Move = rightSide.Move
    this._Flags = rightSide._Flags
    this.SortIndex = rightSide.SortIndex
    this.BaseID = rightSide.BaseID
    this.TargetID = rightSide.TargetID
    
end operator

end namespace

#endif
