#ifndef AutoHooks_bas
#define AutoHooks_bas

#include once "AutoHooks.bi"

'Single source module level arrays
'Reminder: The module construction is not guaranteed
'unless specified (and no one wants to do that).
'So these arrays are not guaranteed to be populated
'the same way between different code versions.
dim _AUTO_HOOK_ALLOC_SINGLE(any) as function(as any ptr = 0) as any ptr
dim _AUTO_HOOK_DEALLOC_SINGLE(any) as sub(byref as any ptr)
dim _AUTO_HOOK_ALLOC_ARRAY(any) as function( as integer, as any ptr = 0) as any ptr
dim _AUTO_HOOK_DEALLOC_ARRAY(any) as sub(byref as any ptr)
dim _AUTO_HOOK_CONSTRUCTOR_ARRAY(any) as sub(as any ptr)
dim _AUTO_HOOK_DESTRUCTOR_ARRAY(any) as sub(as any ptr)
dim _AUTO_HOOK_COPY_ARRAY(any) as sub(as any ptr, as any ptr)
dim _AUTO_HOOK_SWAP_ARRAY(any) as sub(as any ptr, as any ptr)

'API functions
namespace AutoHooks

function IncrementAutoHookArrays() as uinteger<32>
	
	if ubound(_AUTO_HOOK_ALLOC_ARRAY) <> ubound(_AUTO_HOOK_DEALLOC_ARRAY) then
		print "failed to keep array sizes in line"
		sleep
	end if

	dim retVal as integer
	dim increment as integer = 1
	
	if ubound(_AUTO_HOOK_ALLOC_ARRAY) = -1 then
		'First invocation.  Reserve the 0 ID
		increment += 1
	end if
	
	redim preserve _AUTO_HOOK_ALLOC_SINGLE(ubound(_AUTO_HOOK_ALLOC_SINGLE)+increment)
	redim preserve _AUTO_HOOK_DEALLOC_SINGLE(ubound(_AUTO_HOOK_DEALLOC_SINGLE)+increment)
	redim preserve _AUTO_HOOK_ALLOC_ARRAY(ubound(_AUTO_HOOK_ALLOC_ARRAY)+increment)
	redim preserve _AUTO_HOOK_DEALLOC_ARRAY(ubound(_AUTO_HOOK_DEALLOC_ARRAY)+increment)
	redim preserve _AUTO_HOOK_CONSTRUCTOR_ARRAY(ubound(_AUTO_HOOK_CONSTRUCTOR_ARRAY)+increment)
	redim preserve _AUTO_HOOK_DESTRUCTOR_ARRAY(ubound(_AUTO_HOOK_DESTRUCTOR_ARRAY)+increment)
	redim preserve _AUTO_HOOK_COPY_ARRAY(ubound(_AUTO_HOOK_COPY_ARRAY)+increment)
	redim preserve _AUTO_HOOK_SWAP_ARRAY(ubound(_AUTO_HOOK_COPY_ARRAY)+increment)
	
	retVal = ubound(_AUTO_HOOK_ALLOC_ARRAY)
	
	assert(retVal >= 0)
	return cast(uinteger<32>, retVal)
	
end function

sub PopulateAutoHookArrays( _
		inID as uinteger<32>, _
		inAllocSingle as any ptr, _
		inDeallocSingle as any ptr, _
		inAllocArray as any ptr, _
		inDeallocArray as any ptr, _
		inConstructor as any ptr, _
		inDestructor as any ptr, _
		inCopy as any ptr, _
		inSwap as any ptr)
	
	_AUTO_HOOK_ALLOC_SINGLE(inID) = inAllocSingle
	_AUTO_HOOK_DEALLOC_SINGLE(inID) = inDeallocSingle
	_AUTO_HOOK_ALLOC_ARRAY(inID) = inAllocArray
	_AUTO_HOOK_DEALLOC_ARRAY(inID) = inDeallocArray	
	_AUTO_HOOK_CONSTRUCTOR_ARRAY(inID) = inConstructor	
	_AUTO_HOOK_DESTRUCTOR_ARRAY(inID) = inDestructor
	_AUTO_HOOK_COPY_ARRAY(inID) = inCopy
	_AUTO_HOOK_SWAP_ARRAY(inID) = inSwap
	
end sub

function SingleNew(inAutoHookTypeID as uinteger<32>) as function(as any ptr = 0) as any ptr
	assert(inAutoHookTypeID >= 0)
	assert(inAutoHookTypeID <= ubound(_AUTO_HOOK_ALLOC_SINGLE))
	return _AUTO_HOOK_ALLOC_SINGLE(inAutoHookTypeID)
end function

function SingleDelete(inAutoHookTypeID as uinteger<32>) as sub(byref as any ptr)
	assert(inAutoHookTypeID >= 0)
	assert(inAutoHookTypeID <= ubound(_AUTO_HOOK_DEALLOC_SINGLE))
	return _AUTO_HOOK_DEALLOC_SINGLE(inAutoHookTypeID)
end function

function ArrayNew(inAutoHookTypeID as uinteger<32>) as function( as integer, as any ptr = 0) as any ptr
	assert(inAutoHookTypeID >= 0)
	assert(inAutoHookTypeID <= ubound(_AUTO_HOOK_ALLOC_ARRAY))
	return _AUTO_HOOK_ALLOC_ARRAY(inAutoHookTypeID)
end function

function ArrayDelete(inAutoHookTypeID as uinteger<32>) as sub(byref as any ptr)
	assert(inAutoHookTypeID >= 0)
	assert(inAutoHookTypeID <= ubound(_AUTO_HOOK_ALLOC_ARRAY))
	return _AUTO_HOOK_DEALLOC_ARRAY(inAutoHookTypeID)
end function

function Construct(inAutoHookTypeID as uinteger<32>) as sub(as any ptr)
	assert(inAutoHookTypeID >= 0)
	assert(inAutoHookTypeID <= ubound(_AUTO_HOOK_CONSTRUCTOR_ARRAY))
	return _AUTO_HOOK_CONSTRUCTOR_ARRAY(inAutoHookTypeID)
end function

function Destruct(inAutoHookTypeID as uinteger<32>) as sub(as any ptr)
	assert(inAutoHookTypeID >= 0)
	assert(inAutoHookTypeID <= ubound(_AUTO_HOOK_DESTRUCTOR_ARRAY))
	return _AUTO_HOOK_DESTRUCTOR_ARRAY(inAutoHookTypeID)
end function

function Copy(inAutoHookTypeID as uinteger<32>) as sub(as any ptr, as any ptr)
	assert(inAutoHookTypeID >= 0)
	assert(inAutoHookTypeID <= ubound(_AUTO_HOOK_COPY_ARRAY))
	return _AUTO_HOOK_COPY_ARRAY(inAutoHookTypeID)
end function

function _Swap(inAutoHookTypeID as uinteger<32>) as sub(as any ptr, as any ptr)
	assert(inAutoHookTypeID >= 0)
	assert(inAutoHookTypeID <= ubound(_AUTO_HOOK_SWAP_ARRAY))
	return _AUTO_HOOK_SWAP_ARRAY(inAutoHookTypeID)
end function

end namespace

'Auto hook generation
GENERATE_HOOKS(boolean)
GENERATE_HOOKS(byte)
GENERATE_HOOKS(ubyte)
GENERATE_HOOKS(short)
GENERATE_HOOKS(ushort)

'These require specific care due to the <> characters in the keyword.
'GENERATE_HOOKS attempts to create a guard define around
'the name of the type.  In this case, <> are illegal
'characters in #define tokens
#ifndef _INTEGER32_AUTO_HOOKS_GENERATE_GUARD
#define _INTEGER32_AUTO_HOOKS_GENERATE_GUARD
GENERATE_HOOKS_INTERNAL(integer<32>)
#endif

#ifndef _UINTEGER32_AUTO_HOOKS_GENERATE_GUARD
#define _UINTEGER32_AUTO_HOOKS_GENERATE_GUARD
GENERATE_HOOKS_INTERNAL(uinteger<32>)
#endif

#ifndef _INTEGER64_AUTO_HOOKS_GENERATE_GUARD
#define _INTEGER64_AUTO_HOOKS_GENERATE_GUARD
GENERATE_HOOKS_INTERNAL(integer<64>)
#endif

#ifndef _UINTEGER64_AUTO_HOOKS_GENERATE_GUARD
#define _UINTEGER64_AUTO_HOOKS_GENERATE_GUARD
GENERATE_HOOKS_INTERNAL(uinteger<64>)
#endif

GENERATE_HOOKS(integer)
GENERATE_HOOKS(uinteger)
GENERATE_HOOKS(single)
GENERATE_HOOKS(double)

'Fixed length strings cannot be handled
GENERATE_HOOKS(string)

'zstring ptr and wstring ptr (and all pointers)
'fall into the any ptr category

'The catch-all type
namespace AutoHooks
GENERATE_GET_TYPE_ID(any)
end namespace

#ifndef _ANY_PTR_AUTO_HOOKS_GENERATE_GUARD
#define _ANY_PTR_AUTO_HOOKS_GENERATE_GUARD
GENERATE_HOOKS_INTERNAL(any ptr)
#endif

#endif