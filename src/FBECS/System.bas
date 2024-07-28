#ifndef System_bas
#define System_bas

#include once "FBECS.bi"

namespace FBECS

constructor SystemType()
    this.Callback = 0
    this.RateCappedFlag = 0
	this.Enabled = 1
end constructor

constructor SystemType( _
        inName as string, _
        inCallback as sub(FBECS_SYSTEM_CALLBACK_PARAMETERS), _
        byref inQuery as QueryType)

    this.Name = inName
    this.Callback = inCallback
    this.Query = inQuery
    this.RateCappedFlag = 0
	this.Enabled = 1

end constructor

destructor SystemType()
end destructor

operator SystemType.Let ( _
        byref rightSide as SystemType)
    
    this.Name = rightSide.Name
    this.Callback = rightSide.Callback
    this.Query = rightSide.Query
	this.Flags = rightSide.Flags
    'this.RateCappedFlag = rightSide.RateCappedFlag
	'this.Disabled = rightSide.Disabled

end operator

end namespace

#endif
