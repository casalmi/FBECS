#ifndef System_bi
#define System_bi

#include once "QueryIterator.bi"

namespace FBECS

'Forward declare the ecs instance type
type __ECSInstanceType as ECSInstanceType

#define FBECS_SYSTEM_CALLBACK_PARAMETERS _ \
        byref inECS as FBECS.__ECSInstanceType, _ \
        byref inQuery as FBECS.QueryType, _ \
        deltaTime as double

type SystemType
    
    'Human readable name
    dim Name as string
    'The subroutine to run for this system
    dim Callback as sub(FBECS_SYSTEM_CALLBACK_PARAMETERS)
    'The query it's using.  Do not construct implicitly
    dim Query as QueryType
	
	'Flag union
	union
		dim Flags as ubyte
		type
			'Whether or not this system is on the tick system
			dim RateCappedFlag:1 as ubyte
			'Whether or not this system should be run
			dim Enabled:1 as ubyte
		end type
	end union
    
    declare constructor()
    
    declare constructor( _
        inName as string, _
        inCallback as sub(FBECS_SYSTEM_CALLBACK_PARAMETERS), _
        byref inQuery as QueryType)
    
	declare destructor()
	
    declare operator Let ( _
        byref rightSide as SystemType)
    
end type

end namespace

#endif
