#ifndef BitArray_bas
#define BitArray_bas

#include once "BitArray.bi"

constructor BitArrayType()
end constructor

constructor BitArrayType(inBitSize as ubyte, inCount as uinteger<32>)
    
    this.BitSize = inBitSize
    this.Count = inCount
    
    'Guarantee minimum for a short int
    this.ArraySize = ((this.BitSize * this.Count) SHR 3) + 2
    
    this.Array = new ubyte[this.ArraySize]

end constructor

destructor BitArrayType()

    delete [] this.Array

end destructor

function BitArrayType.BitMask() as const ubyte
    
    return (1 SHL this.BitSize) - 1
    
end function

function BitArrayType.Get(index as uinteger) as uinteger
    
    dim retVal as uinteger<16>
    
    retVal = *cast(uinteger<16> ptr, @this.Array[(this.BitSize * index) SHR 3])
    retVal SHR= ((this.BitSize * index) AND 7)
    retVal AND= this.BitMask()
    
    return retVal
    
end function

sub BitArrayType.Set(index as uinteger, inVal as ubyte)
    
    dim setVal as uinteger<16> ptr = cast(uinteger<16> ptr, @this.Array[(this.BitSize * index) SHR 3])
    
    *setVal AND= NOT (this.BitMask() SHL ((this.BitSize * index) AND 7))
    *setVal OR= ((inVal AND this.BitMask()) SHL ((this.BitSize * index) AND 7))
    
end sub

function BitArrayType.SizeInBytes() as uinteger
    
    return this.ArraySize
    
end function

function BitArrayType.GetUsedMemorySize() as uinteger
    
    dim retVal as uinteger
    
    retVal = sizeof(BitArrayType)
    retVal += sizeof(ubyte) + this.SizeInBytes()
    
    return retVal
    
end function

#endif
