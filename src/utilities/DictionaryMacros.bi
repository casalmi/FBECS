
'Copywrite 2024 shadow008
'Anyone is free to use this for any purpose, commercial or private, with or without my permission or knowing.
'
'This is a generic dictionary implementation in freebasic.
'This dictionary should handle all built in freebasic types (though I did not test thoroughly)
'For a User Defined Type to work in this dictionary it MUST:
'  - Have a default constructor (one that takes no arguments)
'  - Have a destructor that cleans up everything properly
'  - Have the Let operator defined wherein it can assign/be assigned to other variables of its type
'    - The compiler's default assignment may be suitable if the data is trivially copyable
'    - Must be able to do a deep enough copy to get identical hash results with copied UDTs
'    - If you are unhappy with the performance implications of a deep copy, use pointers of that type instead
'    - i.e. dim as MyUDT a,b: a = b
'  - (If using as a key) Have the = (equal) operator defined wherein your UDT can be
'    compared for equivalency to other variables of that UDT
'  - (If using as a key) Have defined a hash function with signature:
'    - function _GetHash32 overload (byref inVal as <UDT>) as uinteger<32>
'Furthermore your User Defined Type SHOULD:
'  - (If using as a key) Have a reasonably small size for performance reasons (measured by sizeof(UDT))
'  - Have a default constructor that does not allocate memory (again, performance reasons)
'  - Have a constructor/destructor wherein calling both back-to-back like:
'    UDT.Constructor(): UDT.Destructor()
'    Does not result in memory allocated or deallocated

'KNOWN ISSUES:
'  - wstring is untested entirely
'  - Default type _GetHash32 functions do not work within namespaces, they must be re-defined within the namespace

'Consider using these macros for iterating over key/value pairs:
'DICTIONARY_FOREACH_START(DICT, KEY, VALUE)
'...<code here>...
'DICTIONARY_FOREACH_NEXT

'Optionally use the following as you would "continue for" and "exit for"
'DICTIONARY_FOREACH_CONTINUE
'DICTIONARY_FOREACH_EXIT

#ifndef DictionaryMacros_bi
#define DictionaryMacros_bi

#include once "BitArray.bi"

#macro _DEFINE_HASH32_REAL_FUNCTION(_HASH_TYPE)
declare function _GetHash32 overload (byref inVal as ##_HASH_TYPE) as uinteger<32>
#endmacro

#macro _DEFINE_HASH32_STRING_FUNCTION(_HASH_TYPE)
declare function _GetHash32 overload (byref inVal as ##_HASH_TYPE) as uinteger<32>
#endmacro

'Macro cleaned up at end of file
#macro _GENERATE_HASH32_REAL_FUNCTION(_HASH_TYPE)

function _GetHash32 overload (byref inVal as ##_HASH_TYPE) as uinteger<32>
    
    'FNV-1a hash
    dim retHash as uinteger<32> = 2166136261
    
    dim arrayPtr as ubyte ptr = cast(ubyte ptr, @inVal)
    
    for i as integer = 0 to sizeof(##_HASH_TYPE)-1
        retHash XOR= arrayPtr[i]
        retHash *= 16777619
    next
    
    return retHash

end function
#endmacro

'Macro cleaned up at end of file
#macro _GENERATE_HASH32_STRING_FUNCTION(_HASH_TYPE)
function _GetHash32 overload (byref inVal as ##_HASH_TYPE) as uinteger<32>
    dim retHash as uinteger<32> = 2166136261
	'If the key is a string, build the hash on the string contents.
	if len(inVal) = 0 then
		return 0
	end if

	dim StringPtr as ubyte ptr = StrPtr(inVal)

	for i as integer = 0 to len(inVal)
		retHash XOR= StringPtr[i]
		retHash *= 16777619
	next
    
    return retHash
end function
#endmacro

#ifndef DICTIONARY_FOREACH_START
#macro DICTIONARY_FOREACH_START(DICT, KEY, VALUE)
scope
dim _dictForEachIterator as integer
_dictForEachIterator = (##DICT).ForEachStart()
dim ##VALUE as typeof((##DICT).ForEachNext(0))
dim ##KEY as typeof((##DICT).ForEachNextGetKey(0))
while 1
    VALUE = (##DICT).ForEachNext(_dictForEachIterator)
    if _dictForEachIterator = -1 then
        exit while
    end if
    KEY   = (##DICT).ForEachNextGetKey(_dictForEachIterator)
#endmacro
#endif

#ifndef DICTIONARY_FOREACH_NEXT
#macro DICTIONARY_FOREACH_NEXT
wend
end scope
#endmacro
#endif

#ifndef DICTIONARY_FOREACH_EXIT
#define DICTIONARY_FOREACH_EXIT :exit while:
#endif

#ifndef DICTIONARY_FOREACH_CONTINUE
#define DICTIONARY_FOREACH_CONTINUE  :continue while:
#endif

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''DEFINITION'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

#macro DEFINE_DICTIONARY_TYPE(_KEY_TYPE, _VAL_TYPE, _SIGNATURE)

'Generate the names of the dictionary entry and actual dictionary type.
#define _TYPE_SIG ##_SIGNATURE
#define _ENTRY_SIG DictionaryEntry_##_SIGNATURE

'Guard against duplicate definitions
#ifndef ##_SIGNATURE##_HEADER
#define ##_SIGNATURE##_HEADER

'Configurable defines, with defaults
'These are undefined at the end of the macro

'Minimum size the dictionary can be.  Must be 1 or greater.  Default 8
#ifndef _DICTIONARY_MIN_TABLE_SIZE
	#define _DICTIONARY_MIN_TABLE_SIZE (8UL)
#elseif _DICTIONARY_MIN_TABLE_SIZE <= 0
	#error "_DICTIONARY_MIN_TABLE_SIZE must be > 0"
#endif

'Load factor.  Decides how many elements can be added before the table grows
'Must be a value => 0.5 and < 1.0.  Default 0.66
#ifndef _DICTIONARY_LOAD_FACTOR
	#define _DICTIONARY_LOAD_FACTOR (0.66f)
#elseif _DICTIONARY_LOAD_FACTOR < 0.5 ORELSE _DICTIONARY_LOAD_FACTOR >= 1.0
	#error "_DICTIONARY_LOAD_FACTOR must be >= 0.5 and < 1.0"
#endif

'At some point I should consider profiling the performance of storing
'the key + value separately.  But I don't think it matters much right now.
'Given that the table is sparsely populated, cache coherency is kinda
'thrown out the window already for iteration.
'It may also be worth storing the hash alongside the key/values as well
'this would reduce the potential number of reinserts needed on a key delete
'to only those with matching hashes (real collisions).
type _ENTRY_SIG 
	
	dim Key as _KEY_TYPE
	dim Val as _VAL_TYPE
    
    declare Destructor()
    
end type

'The type name is defined by the user as the _SIGNATURE
type _TYPE_SIG

	declare Constructor()
	declare Constructor(initialSize as uinteger)
	declare Destructor()
    
    'These functions must be called in this order
    declare function ForEachStart() as integer
    declare function ForEachNext(ByRef index as integer) as typeof(_VAL_TYPE) ptr
    declare function ForEachNextGetKey(ByRef index as integer) as typeof(_KEY_TYPE) ptr
    
    'Gets whether or not a key exists in the dictionary
	declare function KeyExists(byref inKey as _KEY_TYPE) as ubyte
    'Combination key exists + get to avoid hashing the key twice
    'Useful when you wish to do something like this in one step:
    'if .KeyExists(...) = 0 then
        'do something when key doesn't exist
    'else
        'value = dict[...]
    '...
    declare function KeyExistsGet(byref inKey as _KEY_TYPE) as typeof(_VAL_TYPE) ptr
	declare function InsertKeyValue(byref inKey as _KEY_TYPE, byref inVal as _VAL_TYPE) as uinteger<32>
	
	'Returns -1 if key was not in dictionary, 
	'otherwise returns what was the index of the deleted entry
	declare function DeleteKey(inKey as _KEY_TYPE) as integer<32>
	declare sub Empty()

	declare function GetEntryCount() as uinteger
	declare function GetTableSize() as uinteger
    
    declare function GetUsedMemorySize() as uinteger
    
	declare operator [] (ByRef key as _KEY_TYPE) ByRef as _VAL_TYPE
    
	private:
		
		const MIN_TABLE_SIZE as uinteger = (_DICTIONARY_MIN_TABLE_SIZE)
		const MAX_TABLE_SIZE as uinteger = (1 SHL 31)
		
		const LOAD_FACTOR as single = (_DICTIONARY_LOAD_FACTOR)
        
        'Array of (key, value) structure
		dim Table as _ENTRY_SIG ptr
        'Size of the Table array
		dim TableSize as uinteger<32>
        'Number of table slots occupied`
		dim EntryCount as uinteger<32>

		dim OccupiedArray as BitArrayType ptr
        
        declare function GetHash(inKey as _KEY_TYPE) as uinteger<32>
		declare function GetIndexByKey(inKey as _KEY_TYPE) as integer<32>
        declare function GetKeyByIndex(index as integer<32>) as typeof(_KEY_TYPE) ptr
		declare sub InsertIntoTable(index as uinteger, byref inKey as _KEY_TYPE, byref inVal as _VAL_TYPE)
		declare sub MoveIntoTable(index as uinteger<32>, byref inKey as _KEY_TYPE, byref inVal as _VAL_TYPE)
		declare function MoveKeyValue(byref inKey as _KEY_TYPE, byref inVal as _VAL_TYPE) as uinteger<32>
		declare function PrepareOpenIndex(byref inKey as _KEY_TYPE) as uinteger<32>
		declare sub ResizeTable(requestedSize as uinteger)
		declare sub SwapDeleteKey(byref inKey as _KEY_TYPE)
        declare sub SwapDeleteValue(byref inVal as _VAL_TYPE)

end type

#undef _DICTIONARY_MIN_TABLE_SIZE
#undef _DICTIONARY_LOAD_FACTOR

#endif 'Guard against multiple definitions

#undef _TYPE_SIG
#undef _ENTRY_SIG

#endmacro

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''IMPLEMENTATION'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''

#macro GENERATE_DICTIONARY_TYPE(_KEY_TYPE, _VAL_TYPE, _SIGNATURE)

#if NOT defined(_SIGNATURE) 
#error "Dictionary was not defined before generating: " _SIGNATURE
#endif

'Generate the names of the dictionary entry and actual dictionary type.
#define _TYPE_SIG ##_SIGNATURE
#define _ENTRY_SIG DictionaryEntry_##_SIGNATURE

#ifndef ##_SIGNATURE##_SOURCE
#define ##_SIGNATURE##_SOURCE

'Undefined at the end of the file
#macro IS_STRING_TYPE(VALUE)
(typeof(##VALUE) = typeof(string)) OR (typeof(##VALUE) = typeof(zstring)) OR (typeof(##VALUE) = typeof(wstring))
#endmacro

Destructor _ENTRY_SIG
#if IS_STRING_TYPE(_KEY_TYPE)
    this.Key = ""
#endif
#if IS_STRING_TYPE(_VAL_TYPE)
    this.Val = ""
#endif
end Destructor

Constructor _TYPE_SIG()
	this.Constructor(8)
end Constructor

Constructor _TYPE_SIG(initialSize as uinteger)
	
	dim size as uinteger
	dim i as uinteger = 0

	if (initialSize < this.MIN_TABLE_SIZE) ORELSE (initialSize > this.MAX_TABLE_SIZE) then
		'If this is > 1 SHL 31 (roughly 2.14 billion), you should
		'probably consider a database.
		size = this.MIN_TABLE_SIZE
	else
		size = 1
		while size < initialSize
			size SHL= 1
		wend
	end if

	this.ResizeTable(size)

end Constructor

Destructor _TYPE_SIG()
	
	if this.Table then
		delete [] this.Table
	end if
	if this.OccupiedArray then
		delete(this.OccupiedArray)
	end if
    
    this.Table = 0
    this.OccupiedArray = 0
    this.TableSize = 0
    this.EntryCount = 0

end Destructor

function _TYPE_SIG.GetEntryCount() as uinteger
	return this.EntryCount
end function

function _TYPE_SIG.GetTableSize() as uinteger
	return this.TableSize
end function

function _TYPE_SIG.GetUsedMemorySize() as uinteger
    
    dim retVal as uinteger
    
    retVal = sizeof(_TYPE_SIG)
    
    retVal += this.TableSize * sizeof(_ENTRY_SIG)
    retVal += this.OccupiedArray->GetUsedMemorySize()
    
    return retVal
    
end function

function _TYPE_SIG.GetHash(inKey as _KEY_TYPE) as uinteger<32>

	if sizeof(##_KEY_TYPE) = 0 then
		return 0
	end if

    return _GetHash32(cast(typeof(##_KEY_TYPE), inKey))

end function

function _TYPE_SIG.GetIndexByKey(inKey as _KEY_TYPE) as integer<32>

	dim hash as uinteger<32> = this.GetHash(inKey)
	dim mask as uinteger<32> = this.TableSize-1
	dim index as uinteger<32>

	dim probeCount as uinteger = 0

	index = hash AND mask

	while probeCount <= this.TableSize
		
		if this.OccupiedArray->Get(index) = 0 then
			return -1
		end if
#if IS_STRING_TYPE(_KEY_TYPE)
        dim firstCharA as const ubyte ptr = strptr(this.Table[index].Key)
        dim firstCharB as const ubyte ptr = strptr(inKey)
        'Compare the first character first, then the rest of the string if it matches
        'Strings default to a null terminator, so no need to check for length
		if firstCharA = firstCharB ORELSE _         'Check the case of exact same string descriptor or both null strings
			firstCharA ANDALSO firstCharB ANDALSO _ 'Check that both strings are not null
			*firstCharA = *firstCharB ANDALSO _     'Check first character
            this.Table[index].Key = inKey then      'Check rest of equality
			return index
		end if
#else
        if this.Table[index].Key = inKey then
			return index
		end if
#endif

		index = ((index * 5) + 1) AND mask
		probeCount += 1
	wend
	
	'Should never reach here
	assert(0)
	return -1

end function

function _TYPE_SIG.GetKeyByIndex(index as integer<32>) as typeof(_KEY_TYPE) ptr
    
    if this.OccupiedArray->Get(index) then
        return @(this.Table[index].Key)
    end if
    
    return cast(typeof(_KEY_TYPE) ptr, 0)
    
end function

sub _TYPE_SIG.InsertIntoTable(index as uinteger, byref inKey as _KEY_TYPE, byref inVal as _VAL_TYPE)

    this.OccupiedArray->Set(index, 1)
	this.Table[index].Key = inKey
	this.Table[index].Val = inVal
	this.EntryCount += 1
	
end sub

sub _TYPE_SIG.MoveIntoTable(index as uinteger<32>, byref inKey as _KEY_TYPE, byref inVal as _VAL_TYPE)
	
	'Does the same as InsertIntoTable, but avoids a deep copy
	'by swapping the contents.
	this.OccupiedArray->Set(index, 1)
	swap this.Table[index].Key, inKey
	swap this.Table[index].Val, inVal
	this.EntryCount += 1
	
end sub

function _TYPE_SIG.PrepareOpenIndex(byref inKey as _KEY_TYPE) as uinteger<32>
	
	'Takes a key and returns an index for where that key must go.
	'This will resize the table if first necessary.
	'The returned index should not be discarded!
	
	if this.EntryCount > int(this.TableSize * this.LOAD_FACTOR) then
		'Keep the table size significantly larger than
		'the item count to minimize collisions.
		this.ResizeTable(this.TableSize SHL 1)
	end if

	dim hash as uinteger<32>
	dim mask as uinteger<32> = this.TableSize-1
	dim newIndex as uinteger<32>

	hash = this.GetHash(inKey)
	newIndex = hash AND mask

	dim probeCount as uinteger = 0

	'Check for collisions
	while probeCount <= this.TableSize
		
		if this.OccupiedArray->Get(newIndex) = 0 then
			return newIndex
		end if
		
		newIndex = ((newIndex * 5) + 1) AND mask
		probeCount += 1

	wend

	'If it ever gets here, the table isn't being resized properly...
	assert(0)
	return cast(uinteger<32>, -1)
	
end function

function _TYPE_SIG.InsertKeyValue(byref inKey as _KEY_TYPE, byref inVal as _VAL_TYPE) as uinteger<32>
    
	dim index as uinteger<32>
	
	index = this.PrepareOpenIndex(inKey)
	this.InsertIntoTable(index, inKey, inVal)
	
	return index
	
end function

function _TYPE_SIG.MoveKeyValue(byref inKey as _KEY_TYPE, byref inVal as _VAL_TYPE) as uinteger<32>
	
	dim index as uinteger<32>
	
	index = this.PrepareOpenIndex(inKey)
	this.MoveIntoTable(index, inKey, inVal)
	
	return index
	
end function

function _TYPE_SIG.ForEachStart() as integer
    return 0
end function

function _TYPE_SIG.ForEachNext(ByRef index as integer) as typeof(_VAL_TYPE) ptr

    if index = -1 then
        return cast(typeof(_VAL_TYPE) ptr, 0)
    end if
    
	'TODO: Check if it's worth optimizing this by checking an entire byte for 0
	'and skipping 8 table entries if it is.
    while index < this.GetTableSize()
        if this.OccupiedArray->Get(index) then
            index += 1
            return @(this.Table[index-1].Val)
        end if
        index += 1
    wend
    
    index = -1
    
    return cast(typeof(_VAL_TYPE) ptr, 0)
    
end function

function _TYPE_SIG.ForEachNextGetKey(ByRef index as integer) as typeof(_KEY_TYPE) ptr
    
    if index < 0 then
        return cast(typeof(_KEY_TYPE) ptr, 0)
    end if
    
    'The -1 is because ForEachNext increments the index before returning
    return this.GetKeyByIndex(index-1)
    
end function

function _TYPE_SIG.KeyExists(byref inKey as _KEY_TYPE) as ubyte	
	return this.GetIndexByKey(inKey) <> -1
end function

function _TYPE_SIG.KeyExistsGet(byref inKey as _KEY_TYPE) as typeof(_VAL_TYPE) ptr
    
    dim index as integer<32>
    
    index = this.GetIndexByKey(inKey)
    
    if index = -1 then
        return 0
    end if
    
    return @this.Table[index].Val
    
end function

function _TYPE_SIG.DeleteKey(inKey as _KEY_TYPE) as integer<32>

	dim retVal as integer<32>
	dim index as integer<32> = this.GetIndexByKey(inKey)
    dim mask as uinteger<32> = this.TableSize-1
	
	dim probeCount as uinteger = 0
	dim insertIndex as uinteger<32>
    
	if index = -1 then
		return -1
	end if

	retVal = index

	'Delete and default construct the current entry
	this.SwapDeleteKey(this.Table[index].Key)
    this.SwapDeleteValue(this.Table[index].Val)

    this.OccupiedArray->Set(index, 0)

    'Check subsequent probe indexes and
    're-insert all hash collisions.
	
	'This function could be sped up by storing the hash
	'alongside the key/value.  The hash itself could be
	'checked for equivalency (instead of the key) and reinserted
	'only if it matches our current deleted key.
    while probeCount <= this.TableSize

        index = ((index * 5) + 1) AND mask
		probeCount += 1
        
		if this.OccupiedArray->Get(index) = 0 then
			exit while
		end if

		'Mark this entry as available.
		'No need to clear the key/value here
        this.OccupiedArray->Set(index, 0)
        this.EntryCount -= 1
        
		'PrepareOpenIndex does not check the table's key contents
		'so it doesn't have to be saved out first
		insertIndex = this.PrepareOpenIndex(this.Table[index].Key)
		
		'Move the key (possibly into the same position)
		'Aliasing data should be OK here
		this.MoveIntoTable(insertIndex, this.Table[index].Key, this.Table[index].Val)

	wend

    this.EntryCount -= 1
	
	return retVal

end function

sub _TYPE_SIG.Empty()
	
	if this.EntryCount > 0 then
		delete [] this.Table
		delete(this.OccupiedArray)
		
		this.Table = 0
		this.OccupiedArray = 0
		this.TableSize = 0
		this.EntryCount = 0

		this.ResizeTable(this.MIN_TABLE_SIZE)
	end if
	
end sub

sub _TYPE_SIG.ResizeTable(requestedSize as uinteger)
	
	'Resize the table and reinsert all items

	if requestedSize = 0 then
		print "DictionaryType.ResizeTable(): New table cannot be size 0"
		return
	end if

	if requestedSize > cast(uinteger<32>, this.MAX_TABLE_SIZE) then
		print "DictionaryType.ResizeTable(): New table size is too large"
		return
	end if

	dim newSize as uinteger = this.MIN_TABLE_SIZE

	while newSize < requestedSize
		newSize SHL= 1
	wend

	if this.Table = 0 then
		'Default case where there is no table yet
		this.Table = new _ENTRY_SIG [newSize]
		this.OccupiedArray = new BitArrayType(1, newSize)
		this.TableSize = newSize
		this.EntryCount = 0
		return
	end if

	'Hang on to the the old stuff for now
	dim oldTable as _ENTRY_SIG ptr = this.Table
	dim oldOccupiedArray as BitArrayType ptr = this.OccupiedArray
	dim oldSize as uinteger = this.TableSize

	this.Table = new _ENTRY_SIG [newSize]
	this.OccupiedArray = new BitArrayType(1, newSize)
	this.TableSize = newSize
    
	dim insertIndex as uinteger<32>
    
	'Reinsert everything from the old table into the new one
	
	'This too could benefit from storing the hash.  We could directly
	'probe the position instead of needing to re-hash first.
	if this.EntryCount > 0 then
        
        'Reset the entry count as it's re-incremented in MoveKeyValue
        this.EntryCount = 0
        
		for i as integer = 0 to oldSize-1
			if oldOccupiedArray->Get(i) <> 0 then
				
				insertIndex = this.PrepareOpenIndex(oldTable[i].Key)
				
				'Avoid doing expensive deep copies when we know everything
				'in the table right now is default constructed
				this.MoveIntoTable(insertIndex, oldTable[i].Key, oldTable[i].Val)

			end if
		next

	end if
	
	delete [] oldTable
	delete(oldOccupiedArray)

end sub

sub _TYPE_SIG.SwapDeleteKey(byref inKey as _KEY_TYPE)

	'Perform a swap delete to ensure a key is destructed and reinitialized
	'This avoids needing to know if a udt has an explicit destructor
	
	dim tempKey as _KEY_TYPE 'Default construct a key
	Swap inKey, tempKey 'Swap the default constructed key with our passed in one
	
	'inKey now holds a default constructed key
	'tempKey is destructed upon function exit
	
end sub

sub _TYPE_SIG.SwapDeleteValue(byref inVal as _VAL_TYPE)
	'Same as above
	dim tempKey as _VAL_TYPE
	Swap inVal, tempKey
end sub

operator _TYPE_SIG.[] (ByRef key as _KEY_TYPE) ByRef as _VAL_TYPE

	dim index as integer<32> = this.GetIndexByKey(key)

	if index <> -1 then
		'Found the resource
		return this.Table[index].Val
	end if
	
	'Copy the key.  This will be swapped out with whatever is in the
	'table already to ensure the old key is destructed.
	dim keyCopy as _KEY_TYPE = key
	'Create a default value to move into the table.
	'Also ensures destruction of the old value.
	dim defaultVal as _VAL_TYPE
	
	'Implictly create the resource if the key doesn't exist.
	'Advantage: ease of use
	'Disdvantage: checking for existance this way creates a resource
	'  which is unlikely to be intended
	'Takeaway: Use "KeyExists()" if you're checking for existance
	index = this.MoveKeyValue(keyCopy, defaultVal)
	return this.Table[index].Val

end operator

#undef _GENERATE_HASH32_REAL_FUNCTION
#undef _GENERATE_HASH32_STRING_FUNCTION

#undef IS_STRING_TYPE

#endif 'Guard against multiple definition

#undef _TYPE_SIG
#undef _ENTRY_SIG

#endmacro

#endif
