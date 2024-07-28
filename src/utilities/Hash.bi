#ifndef Hash_bi
#define Hash_bi

'FNV hashes are in the public domain

'FNV-a1 hash, returns 32 bit integer
declare function FNV1a_32(source as any ptr, size as uinteger) as uinteger<32>

'FNV-a1 hash, returns 64 bit integer
declare function FNV1a_64(source as any ptr, size as uinteger) as uinteger<64>

#endif
