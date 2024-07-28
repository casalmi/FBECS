#ifndef Entity_bas
#define Entity_bas

#include once "FBECS.bi"

namespace FBECS
'Defines cleaned up at end of file
#define ENTITY_ID_MASK (&h00000000ffffffff)
#define GENERATION_MASK (&hffffffff00000000)
#define TARGET_MASK (&hffffffff00000000)

function _GetHash32 overload (byref inVal as FBECS.EntityIDType) as uinteger<32>
    'This value should be pretty unique already
    return inVal.EntityID XOR inVal.Generation
    'return FNV1a_32(@inVal.ID, sizeof(inVal.ID))
end function

GENERATE_DICTIONARY_TYPE(FBECS.EntityIDType, FBECS.EntityIDType, DictionaryType_EntIDEntID)

'constructor EntityIDType()
'    this.ID = -1
'end constructor

static function EntityIDType.Compare cdecl ( _
        byval inIDA as const any ptr, _
        byval inIDB as const any ptr) as long
    
    dim a as EntityIDType ptr = cast(EntityIDType ptr, inIDA)
    dim b as EntityIDType ptr = cast(EntityIDType ptr, inIDB)
    
    return (a->ID < b->ID) OR ((a->ID > b->ID) AND 1)

end function

function EntityIDType.ToString() as string
    dim retString as string = ""
    retString = retString & this.EntityID & ":" & this.Generation
    return retString
end function

property EntityIDType.EntityID() as uinteger<64>
    return this.ID AND ENTITY_ID_MASK
end property

property EntityIDType.EntityID( _
        inEntityID as uinteger<64>)
    this.ID = (this.ID AND (NOT ENTITY_ID_MASK)) OR (inEntityID AND ENTITY_ID_MASK) 
end property

property EntityIDType.Generation() as uinteger<64>
    return (this.ID AND GENERATION_MASK) SHR 32
end property

property EntityIDType.Generation( _
        inGeneration as uinteger<64>)
    this.ID = (this.ID AND ENTITY_ID_MASK) OR _
        (inGeneration SHL 32)
end property

property EntityIDType.TargetID() as uinteger<64>
    return (this.ID AND TARGET_MASK) SHR 32
end property

property EntityIDType.TargetID( _
        inTargetID as uinteger<64>)
    this.ID = (this.ID AND ENTITY_ID_MASK) OR _
        (inTargetID SHL 32)
end property

operator EntityIDType.cast() as uinteger<64>
    return this.ID
end operator

operator EntityIDType.Let(_
        byref rightSide as uinteger<64>)
    this.ID = rightSide
end operator

operator EntityIDType.Let( _
        byref rightSide as integer<64>)
    this.ID = rightSide
end operator

operator EntityIDType.Let( _
        byref rightSide as EntityIDType)
    this.ID = rightSide.ID
end operator

operator = ( _
        byref leftSide as EntityIDType, _
        byref rightSide as EntityIDType) as integer
        
    return leftSide.ID = rightSide.ID
        
end operator

#undef ENTITY_ID_MASK
#undef GENERATION_MASK
#undef TARGET_MASK
#undef ENTITY_TYPE_MASK
#undef ENTITY_TYPE_HIGH_BIT
end namespace

#endif
