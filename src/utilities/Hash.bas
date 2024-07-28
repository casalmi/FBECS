
#include "Hash.bi"

function FNV1a_32(source as any ptr, size as uinteger) as uinteger<32>

	dim retHash as uinteger<32> = 2166136261
	
	for i as integer = 0 to size-1
		retHash XOR= cast(ubyte ptr, source)[i]
		retHash *= 16777619
	next

	return retHash

end function

'FNV-a1 hash, returns 64 bit integer
function FNV1a_64(source as any ptr, size as uinteger) as uinteger<64>

	dim retHash as uinteger<64> = 14695981039346656037

	for i as integer = 0 to size-1
		retHash XOR= cast(ubyte ptr, source)[i]
		retHash *= 1099511628211
	next

	return retHash

end function
