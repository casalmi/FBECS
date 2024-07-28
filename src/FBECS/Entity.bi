#ifndef Entity_bi
#define Entity_bi

#include once "../utilities/Dictionary.bi"

namespace FBECS

type EntityIDType
    
    'Type to uniquely identify an entity
    
    dim as uinteger<64> ID
    
    'DO NOT ADD CONSTRUCTORS
    'declare constructor()
    
    'Comparator function for sorting with crt.bi qsort
    declare static function Compare cdecl ( _
        byval inIDA as const any ptr, _
        byval inIDB as const any ptr) as long
        
    declare function ToString() as string
    
    'EntityID returns just the bottom 32 bits
    declare property EntityID() as uinteger<64>
    declare property EntityID( _
        inEntityID as uinteger<64>)
    
    'Generation returns top 32 bits
    declare property Generation() as uinteger<64>
    declare property Generation( _
        inGeneration as uinteger<64>)
    
    'Target returns top 31 bits
    declare property TargetID() as uinteger<64>
    declare property TargetID( _
        inTargetID as uinteger<64>)
    
    declare operator cast() as uinteger<64>
    
    declare operator Let ( _
        byref rightSide as uinteger<64>)
        
    declare operator Let ( _
        byref rightSide as integer<64>)

    declare operator Let ( _
        byref rightSide as EntityIDType)
    
end type

declare function _GetHash32 overload (byref inVal as FBECS.EntityIDType) as uinteger<32>

DEFINE_DICTIONARY_TYPE(FBECS.EntityIDType, FBECS.EntityIDType, DictionaryType_EntIDEntID)

end namespace

#endif
