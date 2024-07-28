#ifndef AutoHooks_bi
#define AutoHooks_bi

#include once "fbc-int/symbol.bi"

'Automatically creates a set of lifetime related functions
'and packs them into a single ID for retrieval.  This saves
'on needing to save individual function pointers for each
'needed function, and also saves piecemealing the solution
'across multiple different modules.
'Introduces a small runtime overhead, and requires saving
'a 32 bit unsigned integer -somewhere- to retrieve functions.

'-----------------------------------------------------------'
'------------------------CHEAT SHEET------------------------'
'-----------------------------------------------------------'
'
'Declares the signatures for the hooks of a given _TYPE in the AutoHooks namespace
'Typically used in a module header
' - #macro DECLARE_HOOKS(_TYPE)

'Generates the function bodies for the hooks of a given _TYPE in the AutoHooks namespace
'Typically used in the module body
' - #macro GENERATE_HOOKS(_TYPE)
'
'Retrieves an ID for a given _TYPE
'Returns 0 if the type has not had hooks generated for it (or if 'any' type was passed in)
' - #macro GET_AUTO_HOOK_TYPE_ID(_TYPE)

'The following API functions have the same parameter
' * inAutoHookTypeID: A _TYPE ID retrieved from GET_AUTO_HOOK_TYPE_ID(_TYPE)
'
' - AutoHooks.SingleNew(inAutoHookTypeID as uinteger<32>) as function(as any ptr = 0) as any ptr
' - AutoHooks.SingleDelete(inAutoHookTypeID as uinteger<32>) as sub(byref as any ptr)
' - AutoHooks.ArrayNew(inAutoHookTypeID as uinteger<32>) as function(as integer, as any ptr = 0) as any ptr
' - AutoHooks.ArrayDelete(inAutoHookTypeID as uinteger<32>) as sub(byref as any ptr)
' - AutoHooks.Construct(inAutoHookTypeID as uinteger<32>) as sub(byref as any)
' - AutoHooks.Destruct(inAutoHookTypeID as uinteger<32>) as sub(byref as any)\
' - AutoHooks.Copy(inAutoHookTypeID as uinteger<32>) as sub(byref as any, byref as any)

'--------------------------------------------------------------------------'
'---------------------------Begin implementation---------------------------'
'--------------------------------------------------------------------------'

'Shared resources
extern _AUTO_HOOK_ALLOC_SINGLE(any) as function(as any ptr = 0) as any ptr
extern _AUTO_HOOK_DEALLOC_SINGLE(any) as sub(byref as any ptr)
extern _AUTO_HOOK_ALLOC_ARRAY(any) as function( as integer, as any ptr = 0) as any ptr
extern _AUTO_HOOK_DEALLOC_ARRAY(any) as sub(byref as any ptr)
extern _AUTO_HOOK_CONSTRUCTOR_ARRAY(any) as sub(as any ptr)
extern _AUTO_HOOK_DESTRUCTOR_ARRAY(any) as sub(as any ptr)
extern _AUTO_HOOK_COPY_ARRAY(any) as sub(as any ptr, as any ptr)
extern _AUTO_HOOK_SWAP_ARRAY(any) as sub(as any ptr, as any ptr)

'HEADER
namespace AutoHooks

'[Internal use only]
'Increases the array sizes and returns a new type ID
declare function IncrementAutoHookArrays() as uinteger<32>

'[Internal use only]
'Populates the arrays with the function pointers
declare sub PopulateAutoHookArrays( _
		inID as uinteger<32>, _
		inAllocSingle as any ptr, _
		inDeallocSingle as any ptr, _
		inAllocArray as any ptr, _
		inDeallocArray as any ptr, _
		inConstructor as any ptr, _
		inDestructor as any ptr, _
		inCopy as any ptr, _
		inSwap as any ptr)

'Returns a function that allocates a single TYPE item with 'new'
declare function SingleNew(inAutoHookTypeID as uinteger<32>) as function(as any ptr = 0) as any ptr

'Returns a function that deallocates a single TYPE item with 'delete()'
declare function SingleDelete(inAutoHookTypeID as uinteger<32>) as sub(byref as any ptr)

'Returns a function that allocates an array of a TYPE with 'new [count]'
'First argument is the array allocation count.
'Second argument is to be ignored
declare function ArrayNew(inAutoHookTypeID as uinteger<32>) as function(as integer, as any ptr = 0) as any ptr

'Returns a function that deallocates an array of TYPE with 'delete []'
declare function ArrayDelete(inAutoHookTypeID as uinteger<32>) as sub(byref as any ptr)

'Returns a function that default constructs a TYPE
declare function Construct(inAutoHookTypeID as uinteger<32>) as sub( as any ptr)

'Returns a function that destructs a TYPE
declare function Destruct(inAutoHookTypeID as uinteger<32>) as sub( as any ptr)

'Returns a function that calls the assignment operator on the first operand
'i.e. left = right
declare function Copy(inAutoHookTypeID as uinteger<32>) as sub( as any ptr, as any ptr)

'Returns a function that swaps contents of the first and second operand
'i.e. swap left,right
declare function _Swap(inAutoHookTypeID as uinteger<32>) as sub( as any ptr, as any ptr)

end namespace

'Abstracted out only for the 'any' type
#macro DECLARE_GET_TYPE_ID(_TYPE)
declare function GetAutoHookTypeID overload (inVal as _TYPE ptr) as uinteger<32>
#endmacro

'Macro to declare the function signatures for the various types
#macro DECLARE_HOOKS_INTERNAL(_TYPE)
	namespace AutoHooks

	DECLARE_GET_TYPE_ID(_TYPE)
	declare function SingleAllocator overload (inType as _TYPE ptr = 0) as _TYPE ptr
	declare sub SingleDeallocator overload (byref inPtr as _TYPE ptr)
	declare function ArrayAllocator overload (inCount as integer, inType as _TYPE ptr = 0) as _TYPE ptr
	declare sub ArrayDeallocator overload (byref inPtr as _TYPE ptr)
	declare sub DefaultConstruct overload (inVal as _TYPE ptr)
	declare sub DefaultDestruct overload (inVal as _TYPE ptr)
	declare sub DefaultCopy overload (inDst as _TYPE ptr, inSrc as _TYPE ptr)
	declare sub DefaultSwap overload (inLeft as _TYPE ptr, inRight as _TYPE ptr)
	
	end namespace
#endmacro

#macro DECLARE_HOOKS(_TYPE)
	
	'This might have to get monkey-patched if this behavior isn't stable
	#if isTypedef(_TYPE)
		'TODO: Remove this once the bug is fixed in the compiler
		'For some reason, after a certain file size, the __FB_QUERY_SYMBOL__
		'macro stops returning the correct value...
		
		#ifndef _AUTO_HOOKS_##_TYPE##_IS_TYPEDEF
		#define _AUTO_HOOKS_##_TYPE##_IS_TYPEDEF
		#endif
		'Ignore type aliases
	#elseif isTypePointer(_TYPE)
		'Ignore pointers
	#elseif isTypeUDT(_TYPE)
		#ifndef ##_TYPE##_AUTO_HOOKS_DECLARE_GUARD
		#define ##_TYPE##_AUTO_HOOKS_DECLARE_GUARD
		DECLARE_HOOKS_INTERNAL(_TYPE)
		#endif
	#else
		DECLARE_HOOKS_INTERNAL(_TYPE)
	#endif
#endmacro

#macro GENERATE_GET_TYPE_ID(_TYPE)
	function GetAutoHookTypeID overload (inVal as _TYPE ptr) as uinteger<32>
		static myID as uinteger<32> = 0
		
		'The 'any' type is special and will return the null ID 0
	#if typeof(_TYPE) = typeof(any) OR isTypePointer(_TYPE)
		return 0
	#else
		if myID = 0 then
			myID = AutoHooks.IncrementAutoHookArrays()
		end if
		return myID
	#endif
	end function
#endmacro

'Macro to generate the function bodies for the various types
#macro GENERATE_HOOKS_INTERNAL(_TYPE)
	
	'Internal API functions
	namespace AutoHooks

	GENERATE_GET_TYPE_ID(_TYPE)
	
	function SingleAllocator overload (inType as _TYPE ptr = 0) as _TYPE ptr
		return new _TYPE
	end function
	
	sub SingleDeallocator overload (byref inPtr as _TYPE ptr)
		delete(inPtr)
	end sub
	
	function ArrayAllocator overload (inCount as integer, inType as _TYPE ptr = 0) as _TYPE ptr
		return new _TYPE[inCount]
	end function

	sub ArrayDeallocator overload (byref inPtr as _TYPE ptr)
		delete [] inPtr
	end sub
	
	sub DefaultConstruct overload (inVal as _TYPE ptr)
	#if isDataClassInteger(typeof(*inVal)) OR isDataClassFloat(typeof(*inVal))
		inVal = 0
	#else
		'Use the placement new operator
		dim dummy as any ptr = new(inVal) typeof(*inVal)
	#endif
	end sub
	
	sub DefaultDestruct overload (inVal as _TYPE ptr)
	#if NOT isDataClassInteger(typeof(*inVal)) ANDALSO NOT isDataClassFloat(typeof(*inVal))

		#if isDataClassString(typeof(*inVal))
			'Strings can't be "any" initialized?...
			dim default as typeof(*inVal) = ""
		#else
			'Create an uninitialized type
			dim default as typeof(*inVal) = any
			'Clear the memory (unnecessary?)
			Clear(default, 0, sizeof(default))
		#endif
			'Swap with the passed in type
			swap default, *inVal
			'default will be default destructed
			'inVal will be left zeroed out and undefined
	#endif
	end sub
	
	sub DefaultCopy overload (inDst as _TYPE ptr, inSrc as _TYPE ptr)
		'Call the assign operator (Let)
		*inDst = *inSrc
	end sub
	
	sub DefaultSwap overload (inLeft as _TYPE ptr, inRight as _TYPE ptr)
		'Byte-wise swap the contents of the two types
		'This effectively acts as a move.  The caller is responsible for
		'ensuring the contents can be swapped safely with respect to lifetime scoping.
		swap *inLeft, *inRight
	end sub
	
	end namespace
	
	'Module level initialization
	scope
		dim _ID as uinteger<32> = AutoHooks.GetAutoHookTypeID(cast(_TYPE ptr, 0))
		
		AutoHooks.PopulateAutoHookArrays( _
			_ID, _
			procptr(AutoHooks.SingleAllocator, function(as _TYPE ptr = 0) as _TYPE ptr), _
			procptr(AutoHooks.SingleDeallocator, sub(byref as _TYPE ptr)), _
			procptr(AutoHooks.ArrayAllocator, function(as integer, as _TYPE ptr = 0) as _TYPE ptr), _
			procptr(AutoHooks.ArrayDeallocator, sub(byref as _TYPE ptr)), _
			procptr(AutoHooks.DefaultConstruct, sub(as _TYPE ptr)), _
			procptr(AutoHooks.DefaultDestruct, sub(as _TYPE ptr)), _
			procptr(AutoHooks.DefaultCopy, sub(as _TYPE ptr, as _TYPE ptr)), _
			procptr(AutoHooks.DefaultSwap, sub(as _TYPE ptr, as _TYPE ptr)))
	end scope

#endmacro

#macro GENERATE_HOOKS(_TYPE)

	'TODO: remove the defined() check when the bug is fixed (see DECLARE_HOOKS)
	#if isTypedef(_TYPE) OR defined(_AUTO_HOOKS_##_TYPE##_IS_TYPEDEF)
	'Ignore type aliases
	#elseif isTypeUDT(_TYPE)
		#ifndef ##_TYPE##_AUTO_HOOKS_GENERATE_GUARD
		#define ##_TYPE##_AUTO_HOOKS_GENERATE_GUARD
		GENERATE_HOOKS_INTERNAL(_TYPE)
		#endif
	#else
		GENERATE_HOOKS_INTERNAL(_TYPE)
	#endif
#endmacro

'API macro for getting a type's auto hook ID
#macro GET_AUTO_HOOK_TYPE_ID(_TYPE)
	AutoHooks.GetAutoHookTypeID(cast(typeof(_TYPE) ptr, 0))
#endmacro

'Auto hook declaration

'Built in types
DECLARE_HOOKS(boolean)
DECLARE_HOOKS(byte)
DECLARE_HOOKS(ubyte)
DECLARE_HOOKS(short)
DECLARE_HOOKS(ushort)
DECLARE_HOOKS(integer<32>)
DECLARE_HOOKS(uinteger<32>)
DECLARE_HOOKS(integer<64>)
DECLARE_HOOKS(uinteger<64>)
DECLARE_HOOKS(integer)
DECLARE_HOOKS(uinteger)
DECLARE_HOOKS(single)
DECLARE_HOOKS(double)

'Fixed length strings cannot be handled
DECLARE_HOOKS(string)

'The catch-all type
namespace AutoHooks
DECLARE_GET_TYPE_ID(any)
end namespace

'The any type requires manual concatonation
#ifndef _ANY_PTR_AUTO_HOOKS_DECLARE_GUARD
#define _ANY_PTR_AUTO_HOOKS_DECLARE_GUARD
DECLARE_HOOKS_INTERNAL(any ptr)
#endif

#endif
