#ifndef DictionaryHeader_bi
#define DictionaryHeader_bi

#include "DictionaryMacros.bi"

_DEFINE_HASH32_REAL_FUNCTION(boolean)
_DEFINE_HASH32_REAL_FUNCTION(ubyte)
_DEFINE_HASH32_REAL_FUNCTION(byte)
_DEFINE_HASH32_REAL_FUNCTION(ushort)
_DEFINE_HASH32_REAL_FUNCTION(short)
_DEFINE_HASH32_REAL_FUNCTION(uinteger<32>)
_DEFINE_HASH32_REAL_FUNCTION(integer<32>)
_DEFINE_HASH32_REAL_FUNCTION(uinteger<64>)
_DEFINE_HASH32_REAL_FUNCTION(integer<64>)
 
_DEFINE_HASH32_REAL_FUNCTION(uinteger)
_DEFINE_HASH32_REAL_FUNCTION(integer)
 
_DEFINE_HASH32_REAL_FUNCTION(single)
_DEFINE_HASH32_REAL_FUNCTION(double)
 
_DEFINE_HASH32_REAL_FUNCTION(any ptr)
 
_DEFINE_HASH32_STRING_FUNCTION(string)

'''''''''''''''''''''''''''''''''''Generic dictionaries'''''''''''''''''''''''''''''''''''
'Add any dictionary that uses only built in types here

'Dictionaries that use UDTs should be defined in the first
'module that defines the UDT.

DEFINE_DICTIONARY_TYPE(string, ushort, DictionaryType_StrUshort)
DEFINE_DICTIONARY_TYPE(string, integer<32>, DictionaryType_StrInt)

#endif
