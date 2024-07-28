
#include once "dprint.bi"
#include once "DynamicArray.bi"

'Macro cleaned up at end of file
#macro GenPush(inType)
function DynamicArrayType.Push overload (item as ##inType) as uinteger

    dim retVal as uinteger = this.Count
    
    if this.Count >= this.Size then
        dim newSize as uinteger<32> = iif(this.Size = 0, 1, this.Size SHL 1)
        this.Resize(newSize)
    end if
    
    cast(typeof(##inType) ptr, this.Array)[this.Count] = item
    
    this.Count += 1

    return retVal
    
end function
#endmacro

constructor DynamicArrayType(inElementSize as uinteger)

    this.Constructor(inElementSize, 0)

end constructor

constructor DynamicArrayType(inElementSize as uinteger, initialArraySize as uinteger)
    
    assert(initialArraySize >= 0)
    assert(this.Array = 0)
    
    this.Count = 0
    this.Size = initialArraySize
    this.ElementSize = inElementSize
    
    this.Array = 0
    
    if initialArraySize > 0 then
        this.Resize(initialArraySize)
    end if
    
end constructor

destructor DynamicArrayType()
    
    if this.Array then
        delete [] this.Array
        this.Array = 0
    end if
    
    this.Count = 0
    this.Size = 0
    this.ElementSize = 0
    
end destructor

'Gen subs with the following signature:
'sub DynamicArrayType.Push overload (item as <type>)

'Integers
GenPush(boolean)
GenPush(byte)
GenPush(ubyte)
GenPush(short)
GenPush(ushort)
GenPush(integer<32>)
GenPush(uinteger<32>)
GenPush(integer<64>)
GenPush(uinteger<64>)
'FP
GenPush(single)
GenPush(double)
'String
GenPush(string)
GenPush(zstring ptr)
'Pointers
GenPush(any ptr)

function DynamicArrayType.PushUDT(item as any ptr) as uinteger
    
    assert(item <> 0)
    
    dim retVal as uinteger = this.Count
    
    if this.Count >= this.Size then
        dim newSize as uinteger<32> = iif(this.Size = 0, 1, this.Size SHL 1)
        this.Resize(newSize)
    end if
	
    memcpy(@(this[this.Count]), item, this.ElementSize)
    
    this.Count += 1

    return retVal
    
end function

function DynamicArrayType.Reserve overload () as uinteger
    
    dim retVal as uinteger = this.Count
    
    this.Count += 1
    
    if this.Count >= this.Size then
        dim newSize as uinteger<32> = iif(this.Size = 0, 1, this.Size SHL 1)
        this.Resize(newSize)
    end if
    
    return retVal
    
end function

function DynamicArrayType.Reserve overload (inCount as uinteger) as uinteger
    
    dim retVal as uinteger = this.Count
    
    this.Count += inCount
    
    if this.Count >= this.Size then
        dim newSize as uinteger<32> = iif(this.Size = 0, 1, this.Size)
		while newSize <= this.Count
			newSize SHL= 1
		wend
        this.Resize(newSize)
    end if
    
    return retVal
    
end function

function DynamicArrayType.PreAllocate(inCount as uinteger) as uinteger
	
	if inCount = 0 then
		return 0
	end if
	
	dim newCount as uinteger<32> = this.Count
	dim retVal as uinteger = this.Count
	
	if newCount >= this.Size then
		dim newSize as uinteger<32> = 1
		
		while newCount
			newCount SHR = 1
			newSize SHL= 1
		wend
		
		this.Resize(newSize)
		
	end if
	
	return retVal
	
end function

function DynamicArrayType.Remove(index as uinteger) as integer

    if this.Count = 0 then
        return 0
    end if
    
    'dim retVal as uinteger = this.Count-1
    
    'Remove an item from the array and re-densify
    
    'Move the item from the back of the list to the new location
    'MoveItem checks for fromIndex = toIndex
    this.MoveItem(this.Count-1, index)
    
    'Clear the item at the back of the list
    '(may be unnecessary to do this, consider removing)
    'memset(@this[this.Count-1], 0, this.ElementSize)
    
    this.Count -= 1
    
    if this.Count < this.Size SHR 1 then
        this.Resize(this.Size SHR 1)
    end if
    
    'Return the new end of the list
    return iif(index >= this.Count, this.Count-1, index)
    
end function

sub DynamicArrayType.Resize(newSize as uinteger)

    dim i as uinteger
    dim tempArray as ubyte ptr = 0
    
    if newSize > 0 then
        tempArray = new ubyte[newSize*this.ElementSize]
        memset(tempArray, 0, newSize * this.ElementSize)
    end if
    
    if tempArray ANDALSO this.Array then
        
        'We probably have data to copy
        
        if this.Size <= newSize then
            'Increasing in size, copy current array count elements
            memcpy(tempArray, this.Array, this.Size * this.ElementSize)
        else
            'Decreasing in size, copy new array count elements
            memcpy(tempArray, this.Array, newSize * this.ElementSize)
        end if
        
    end if
    
    if this.Array then
        delete [] this.Array
        this.Array = 0
    end if
    this.Array = tempArray

    this.Size = newSize

end sub

sub DynamicArrayType.ResizeNoSave(newSize as uinteger)
	
	if this.Size = newSize ANDALSO this.Array <> 0 then
		'Happy path where the array already has the right size
		memset(this.Array, 0, this.Size * this.ElementSize)
		this.Count = 0
		return
	end if
	
    if this.Array then
        delete [] this.Array
        this.Array = 0
    end if
    
    if newSize > 0 then
        this.Array = new ubyte[newSize*this.ElementSize]
    end if
    
    this.Size = newSize
    
    this.Count = 0

end sub

sub DynamicArrayType.MoveItem(fromIndex as uinteger, toIndex as uinteger)
    
    assert(fromIndex >= 0 ANDALSO fromIndex < this.Count)
    assert(toIndex >= 0 ANDALSO toIndex < this.Count)
    
    if fromIndex = toIndex then
        return
    end if
    
    memcpy(@this[toIndex], @this[fromIndex], this.ElementSize)
    memset(@this[fromIndex], 0, this.ElementSize)
    
end sub

sub DynamicArrayType.SwapItems(indexA as uinteger, indexB as uinteger)
    
    assert(indexA >= 0 ANDALSO indexA < this.Count)
    assert(indexB >= 0 ANDALSO indexB < this.Count)
    
    if indexA = indexB then
        return
    end if
    
    dim tempItem(this.ElementSize-1) as ubyte
    
    'Copy the item at indexA into the temp item
    memcpy(@tempItem(0), @this[indexA], this.ElementSize)
    
    'Move item at indexB to indexA's location
    this.MoveItem(indexB, indexA)
    
    'Finally, move the temp item into indexB's location
    memcpy(@this[indexB], @tempItem(0), this.ElementSize)
    
end sub

static sub DynamicArrayType.Move(byref leftSide as DynamicArrayType, byref rightSide as DynamicArrayType)

    rightSide.Count = leftSide.Count
    rightSide.Size = leftSide.Size
    rightSide.ElementSize = leftSide.ElementSize
    rightSide.Array = leftSide.Array
    
    leftSide.Count = 0
    leftSide.Size = 0
    'leftSide.ElementSize = 0 'This doesn't need to be changed
    leftSide.Array = 0

end sub

function DynamicArrayType.GetArrayPointer() as any ptr
    return cast(any ptr, this.Array)
end function

function DynamicArrayType.GetUsedMemorySize() as uinteger
    
    dim retVal as uinteger
    
    retVal = sizeof(DynamicArrayType)
    
    retVal += this.ElementSize * this.Size
    
    return retVal
    
end function

operator DynamicArrayType.[] (index as uinteger) ByRef as ubyte
    
    'assert((index > 0) ANDALSO (index <= this.Count) ANDALSO (index < this.Size))
	
	if (index < 0) ORELSE (index > this.Count) ORELSE (index >= this.Size) then
		dprint("Dynamic array illegal access: ";index;" < 0 OR ";index;" > ";this.Count;" OR ";index;" >= ";this.Size)
		sleep
	end if
	
    return this.Array[index*this.ElementSize]
    
end operator

operator DynamicArrayType.Let (byref rightSide as DynamicArrayType)
    
    assert(this.ElementSize = rightSide.ElementSize)

    this.ResizeNoSave(rightSide.Size)
	
	this.Size = rightSide.Size
    
    this.Count = rightSide.Count
    
	if this.Size then
		memcpy(@this[0], @rightSide[0], this.Size * this.ElementSize)
	end if

end operator

#undef GenPush
