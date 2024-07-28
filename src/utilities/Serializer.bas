#ifndef Serializer_bas
#define Serializer_bas

#include once "dprint.bi"
#include once "Serializer.bi"

'Create a serializer from a type, including a user defined type

namespace FBSerializer

constructor SerializerMemberInfoType( _
		inType as MemberTypeEnum, _
		inSize as uinteger<32>, _
		inOffset as integer<32>, _
		inName as zstring ptr, _
		inSerializer as sub(as any ptr, byref as StreamInterface), _
		inDeserializer as sub(as any ptr, byref as StreamInterface), _
		inToJSON as function(as any ptr) as string, _
		inValidateJSON as function(as any ptr, byref as StreamInterface) as string, _
		inFromJSON as function(as any ptr, byref as StreamInterface) as string, _
		inSubTypeSize as uinteger<32> = 0, _
		inSubTypeAllocator as function(as any ptr, as integer) as any ptr = 0, _
		inArrayDescriptorPtr as const FBC.FBARRAY ptr = 0, _
		inArrayCount as uinteger<32> = 0, _
		inArrayCountPointerSize as uinteger<32> = 0, _
		inArrayCountPointerOffset as integer<32> = 0)

	this.BaseType._Type = inType
	this.BaseType.Size = inSize
	this.BaseType.Offset = inOffset
	this.BaseName = inName
	
	this.Serializer = inSerializer
	this.Deserializer = inDeserializer
	this.ToJSON = inToJSON
	this.ValidateJSON = inValidateJSON
	this.FromJSON = inFromJSON
	
	this.SubType.Size = inSubTypeSize
	this.SubType.Allocator = inSubTypeAllocator
	
	this.PtrArray.Count = inArrayCount
	this.PtrArray.Size = inArrayCountPointerSize
	
	if inSerializer = ProcPtr(FBSerializer.SerializeToBinary, sub(as any ptr, stream as StreamInterface)) ANDALSO _
		inType = _SIMPLE then
		
		'It MIGHT be wrong, but I'm gonna guess it's a fixed string
		this.BaseType._TYPE = _FIXED_STRING
		dprint("FBSerializer WARNING: Fixed length string detected for member: ";*this.BaseName;"? These are not handled properly.")
	end if

	if inArrayDescriptorPtr then
		
		if inArrayDescriptorPtr->dimensions = 0 then
			dprint("FBSerializer ERROR: FBSerializer does not auto-support variable length FB arrays for member: ";*this.BaseName)
			dprint("Please specify a custom serializer")
			sleep
		end if
		
		'Make a copy of the array descriptor parts we care about
		this.FBArray.element_len = inArrayDescriptorPtr->element_len
		this.FBArray.dimensions = inArrayDescriptorPtr->dimensions
		
		for i as integer = 0 to this.FBArray.dimensions - 1
			this.FBArray.dimTb(i) = inArrayDescriptorPtr->dimTb(i)
		next
		
		if this.FBArray.dimTb(0).lbound <> 0 then
			'Adjust the offset to the correct location
			'if the array does not start at 0
			this.BaseType.Offset += this.FBArray.dimTb(0).lbound * this.FBArray.element_len
		end if
		
	elseif inArrayCountPointerOffset <> 0 then
		
		'We need to generate the offset from the array's offset
		this.PtrArray.CountPtrOffset = inArrayCountPointerOffset - this.BaseType.Offset
		
	end if
	
end constructor

destructor SerializerMemberInfoType()
end destructor

''''''''''''''''''''''''''''''''''''''''''''''''''''''''
'''''''''''''''''''JSON PARSING START'''''''''''''''''''
function GetNextToken(byref stream as StreamInterface) as ubyte
	
	dim char as ubyte = 0
	
	while stream.Read(@char, 1)

		select case as const char
		
			case 9,  _ 'Horizontal tab
				 10, _ 'Newline
				 11, _ 'Vertical tab
				 12, _ 'Form feed
				 13, _ 'Carraige return
				 32    'Space
				
				'Skip whitespace
				
			case else
				'Anything else is a token
				exit while
			
		end select
		
		'Reset the value in case we hit an early end-of-stream
		char = 0
		
	wend
	
	return char
	
end function

function GetErrorContext(byref stream as StreamInterface) as string
	
	dim char as ubyte = 0
	dim count as integer = 64
	dim retString as string = ""
	
	if stream.Tell() < count then
		count = stream.Tell()
	end if
	
	stream.Seek(stream._SEEK_CUR, count * -1)
	
	for i as integer = 0 to count - 1
		stream.Read(@char, 1)
		retString &= chr(char)
	next
	
	retString &= !"\n" & Space(count-1) & "^"
	
	return retString
	
end function

function ReadJSONNull( _
		byref stream as StreamInterface) as string
	
	'This does not have an out value.
	'If the return string is null, the value was successfully read
	'Otherwise, an error string is returned
	
	dim char as ubyte = 0
	dim nullString as string = ""
	
	while stream.Read(@char, 1)
		
		select case as const char
			case asc("n"), asc("u"), asc("l")
				'Do nothing
			case else
				'Set the char back
				stream.Seek(stream._SEEK_CUR, -1)
				exit while
		end select
		
		nullString &= chr(char)
		char = 0
		
	wend
	
	if nullString <> "null" then
		return "Expected 'null' got " & nullString
	end if
	
	return ""
	
end function

function ReadJSONBoolean( _
		byref stream as StreamInterface, _
		outBool as boolean ptr = 0) as string
	
	dim char as ubyte = 0
	dim trueOrFalse as ubyte = 0
	dim boolString as string = ""
	
	while stream.Read(@char, 1)
		
		select case as const char
            case asc("t"), asc("r"), asc("u"), asc("e"), asc("f"), asc("a"), asc("l"), asc("s")
				'Do nothing
            case else
                'Set the char back
                stream.Seek(stream._SEEK_CUR, -1)
                exit while
        end select
		
		boolString &= chr(char)
		
		char = 0
		
	wend
	
	if boolString = "false" then
        trueOrFalse = false
    elseif boolString = "true" then
        trueOrFalse = true
    else
        return "Expected 'true' or 'false' got '" & boolString & "'"
    end if
	
	if outBool then
		*outBool = trueOrFalse
	end if
	
	return ""
	
end function

function ReadJSONNumber( _
		byref stream as StreamInterface, _
		outNumber as double ptr = 0) as string

	dim char as ubyte = 0
	dim numberString as string = ""
	dim negativeCount as ubyte = 0
    dim periodCount as ubyte = 0
    dim exponentCount as ubyte = 0
	
	dim startCursor as integer = stream.Tell()
	dim readError as ubyte = 0
	
	'TODO: Test exotic values like 5.987E-123 etc
	
	while stream.Read(@char, 1)
		
		select case as const char
            case asc("-")
                negativeCount += 1
				readError = iif(stream.Tell()-1 > startCursor ANDALSO exponentCount <> 1, 1, 0)
            case asc("+")
				'Ignored
            case asc(".")
                periodCount += 1
				readError = iif(periodCount > 1, 1, 0)
            case asc("E"), asc("e")
                exponentCount += 1
				readError = iif(exponentCount > 1, 1, 0)
            case asc("0") to asc("9")
				'Do nothing
            case else
				'Undo this byte read
				stream.Seek(stream._SEEK_CUR, -1)
                exit while
        end select
		
		numberString &= chr(char)
		
		char = 0
		
		if readError then
			return "Expected valid json number got '" & numberString & "'"
		end if
		
	wend
	
	if outNumber then
		*outNumber = CDbl(numberString)
	end if
	
	return ""

end function

function ReadJSONString( _
		byref stream as StreamInterface, _
		outString as string ptr = 0) as string
	
	dim char as ubyte = 0
	dim addChar as ubyte = 0
	dim strString as string = ""
	
	dim escapedChar as ubyte = 0
	
	'TODO: add support for \u#### escaped characters
	
	char = FBSerializer.GetNextToken(stream)
	if char <> asc(!"\"") then
		return !"Expected quotation marks \" got " & chr(char)
	end if
	
	while stream.Read(@char, 1)
		
		if char = asc(!"\"") ANDALSO escapedChar = 0 then
			exit while
		end if
		
		addChar = char
		
		if escapedChar = 1 then
            'We should add an escaped character to the string
			'These are all JSON supports
			select case as const char
				case asc("b")
					addChar = asc(!"\b")
				case asc("f")
					addChar = asc(!"\f")
				case asc("n")
					addChar = asc(!"\n")
				case asc("r")
					addChar = asc(!"\r")
				case asc("t")
					addChar = asc(!"\t")
				case asc(!"\"")
					addChar = asc(!"\"")
				case asc("\")
					addChar = asc("\")
				case else
					'Not a valid escape sequence
					'Add the \ back in
					if outString then
						strString &= "\"
					end if
			end select
			
        end if
		
		escapedChar = iif(char = asc(!"\"") ANDALSO escapedChar = 0, 1, 0)
		
		if char = 0 then
			return "Unexpected end of stream. Unclosed string in the JSON."
		end if
		
		if escapedChar = 0 ANDALSO outString then
			strString &= chr(addChar)
		end if
		
		char = 0
		
	wend
	
	if outString then
		*outString = strString
	end if
	
	return ""
	
end function

function MatchQuotationMarks(byref stream as StreamInterface) as string
	
	return FBSerializer.ReadJSONString(stream)
	
end function

declare function MatchCurlyBracket(byref stream as StreamInterface) as string

function MatchSquareBracket(byref stream as StreamInterface) as string
	
	dim char as ubyte = 0
	dim retString as string = ""
	
	while stream.Read(@char, 1)
	
		select case as const char
			case asc(!"\"")
				stream.Seek(stream._SEEK_CUR, -1)
				retString &= FBSerializer.MatchQuotationMarks(stream)
			case asc("[")
				retString &= FBSerializer.MatchSquareBracket(stream)
			case asc("{")
				retString &= FBSerializer.MatchCurlyBracket(stream)
			case asc("]")
				'Found match
				exit while
			case else
				'Skip over everything else
		end select
		
		if len(retString) > 0 then
			return retString
		end if
		
		char = 0
	wend
	
	'The stream head is now right after the ]
	return ""
	
end function

function MatchCurlyBracket(byref stream as StreamInterface) as string
	
	dim char as ubyte = 0
	dim retString as string = ""
	
	while stream.Read(@char, 1)
	
		select case as const char
			case asc(!"\"")
				stream.Seek(stream._SEEK_CUR, -1)
				retString &= FBSerializer.MatchQuotationMarks(stream)
			case asc("[")
				retString &= FBSerializer.MatchSquareBracket(stream)
			case asc("{")
				retString &= FBSerializer.MatchCurlyBracket(stream)
			case asc("}")
				'Found match
				exit while
			case else
				'Skip over everything else
		end select
		
		if len(retString) > 0 then
			return retString
		end if
		
		char = 0
	wend
	
	'The stream head is now right after the ]
	return ""
	
end function

function SkipJSONValue(byref stream as StreamInterface) as string
	
	dim char as ubyte = FBSerializer.GetNextToken(stream)
	dim retString as string = ""
	
	select case as const char
		
		'Each type handles its entire scope
		'Except the Match [] {} functions, but it doesn't matter for them
		stream.Seek(stream._SEEK_CUR, -1)
		
		case asc("{")
			retString = FBSerializer.MatchCurlyBracket(stream)
        case asc("[")
			retString = FBSerializer.MatchSquareBracket(stream)
        case asc(!"\"")
			retString = FBSerializer.ReadJSONString(stream)
        case asc("-"), asc("."), asc("0") to asc("9")
			retString = FBSerializer.ReadJSONNumber(stream)
        case asc("f"), asc("t")
            'Note that uppercase T or F is invalid json
            retString = FBSerializer.ReadJSONBoolean(stream)
        case asc("n")
            'Note, again, that uppercase N is invalid
			retString = FBSerializer.ReadJSONNull(stream)
        case else
			retString = "Expected start of JSON value got '" & chr(char) & "'"
		
	end select

	return retString
	
end function

function FindNextJSONArrayValue( _
		byref stream as StreamInterface, _
		byref readState as ubyte, _
		outHasValue as ubyte ptr) as string
	
	'This function iterates over an array and yields when the next value is encountered
	
	'Returns a string of any error encountered
	'ReadState will be a state variable that will be repeatedly passed to this function
	'    - NOTE: This value must be reset between different json streams or different arrays
	'Returns, in outHasValue:
	' - 0 if end of array was encountered, stream will point to char after the array
	' - 1 if there is a value, stream will point to the start of the value
	'If an error string was returned, outHasValue is set to 0

	'This will unfortunately allow for a malformed array with a starting comma like so:
	'"key": [, value, value]
	
	dim char as ubyte = 0
	dim retString as string = ""
	dim expectValue as ubyte = 0
	
	'The value held in readState is like so:
	'1 = value
	'2 = comma , or array close ]
	
	if readState = 0 then
		readState = 1
	end if
	
	do
		
		char = FBSerializer.GetNextToken(stream)
		
		select case as const char
			case asc(",")
				if expectValue = 1 then
					retString = "Expected value after comma (,) in array"
				end if
				expectValue = 1
				
			case asc("]")
				if expectValue = 1 then
					retString = "Expected value after comma (,) in array"
				end if
				
				'End of array
				readState = 0
				*outHasValue = 0
				return retString
				
			case 0
				retString = "Unexpected end of stream. Unclosed array in the JSON."
				
			case else
				stream.Seek(stream._SEEK_CUR, -1)
				readState = 2
				*outHasValue = 1
				return retString
				
		end select
		
		if len(retString) > 0 then
			'Bail on error
			exit do
		end if
		
	loop while char <> 0
	
	*outHasValue = 0
	
	return retString
	
end function

function GetJSONArrayLength( _
		byref stream as StreamInterface, _
		outLength as integer ptr) as string
	
	'Returns a string of any error encountered
	'Returns the element count in outLength if supplied
	'The stream is returned to the cursor position it started in
	
	dim char as ubyte = 0
	dim count as integer = 0
	dim retString as string = ""
	dim readState as ubyte
	dim hasValue as ubyte = 0
	
	dim saveCursor as integer = stream.Tell()
	
	char = FBSerializer.GetNextToken(stream)
	if char <> asc("[") then
		stream.Seek(stream._SEEK_CUR, saveCursor - stream.Tell())
		return "Expected '[' got " & chr(char)
	end if
	
	do
		FBSerializer.FindNextJSONArrayValue(stream, readState, @hasValue)
		
		if hasValue then
			count += 1
			retString = FBSerializer.SkipJSONValue(stream)
		end if
		
		if len(retString) > 0 then
			exit do
		end if
		
	loop while hasValue <> 0

	if outLength then
		*outLength = count
	end if
	
	'Reset the stream back to the start
	stream.Seek(stream._SEEK_CUR, saveCursor - stream.Tell())
	
	return retString
	
end function

function ReadJSONArray( _
		byref stream as StreamInterface, _
		outPtr as any ptr, _
		elementSize as integer, _
		inCallback as function(as any ptr, byref as StreamInterface) as string) as string
	
	'This function assumes that outPtr was properly allocated
	
	dim char as ubyte = 0
	dim retString as string = ""
	dim cursor as integer
	dim currPtr as any ptr = outPtr
	dim readState as ubyte
	dim hasValue as ubyte = 0
	
	char = FBSerializer.GetNextToken(stream)
	if char <> asc("[") then
		return "Expected '[' got " & chr(char)
	end if
	
	do
		FBSerializer.FindNextJSONArrayValue(stream, readState, @hasValue)
		
		if hasValue then
			cursor = stream.Tell()
				
			retString = inCallback(currPtr, stream)
			currPtr += elementSize
			
			if cursor = stream.Tell() then
				retString &= ":Read JSON array: Validate/DeserializeFromJSON did not move the stream"
			end if
		end if
		
		if len(retString) > 0 then
			exit do
		end if
		
	loop while hasValue <> 0
	
	return retString

end function

function GetNextJSONKeyValue( _
		byref stream as StreamInterface, _
		byref readState as ubyte, _
		outKey as string ptr, _
		outHasValue as ubyte ptr) as string

	'Gets the next key from an object and moves the stream head to 
	'the start of that key's value.
	'Returns a string of any error encountered
	'ReadState will be a state variable that will be repeatedly passed to this function
	'    - NOTE: This value will be reset if the object close is encountered
	'Returns in outKey the key as a string
	'Returns in outHasValue 1 if there's a value, 0 if not (object closed)

	dim char as ubyte = 0
	dim retString as string = ""
	
	'Start by expecting to read a key
	'The value held in readState is like so:
	'1 = key
	'2 = colon
	'3 = value
	'4 = comma , or object close }
	
	dim key as string = ""
	dim foundKey as ubyte
	
	if readState = 0 then
		readState = 1
	end if
	
	*outHasValue = 0
	
	do
		
		'Check if the object is closed
		char = FBSerializer.GetNextToken(stream)
		if char = asc("}") then
			if readState = 2 then
				retString = "Unexpected end of object. Expected colon after key '" & key & "'"
			elseif readState = 3 then
				retString = "Unexpected end of object. Expected value after colon"
			end if
			readState = 0
			exit do
		end if
		stream.Seek(stream._SEEK_CUR, -1)

		'This shit again....
		'If I declare switch case as const, compiling this with the gcc backend
		'will throw a warning about an uninitialized variable.
		'TODO: Reproduce this minimally and file a bug report.
		'select case as const readToken
		select case readState
		
			case 1
				retString = FBSerializer.ReadJSONString(stream, @key)
				readState = 2
				
			case 2
				char = FBSerializer.GetNextToken(stream)
				if char <> asc(":") then
					retString = "Expected colon : after key got '" & chr(char) & "'"
				end if
				readState = 3
				
			case 3
			
				*outKey = key
				*outHasValue = 1
				readState = 4
				return retString
				
			case 4
				
				char = FBSerializer.GetNextToken(stream)
				
				if char = asc(",") then
					readState = 1
				elseif char = asc("}") then
					'Object close will be caught in the next iteration
					stream.Seek(stream._SEEK_CUR, -1)
				else
					retString = "Expected , or object close } in object got " & chr(char)
				end if
			
			case else
				
				retString = "GetNextJSONKeyValue error"
				
		end select
		
		if len(retString) > 0 then
			retString &= !"\n" & FBSerializer.GetErrorContext(stream)
			exit do
		end if
		
	loop while char <> 0
	
	'Fail state
	readState = 5

end function

function JSONPrettyPrint overload ( _
		byref stream as StreamInterface, _
		tabWidth as uinteger = 4) as string
	
	dim char as ubyte = 0
	dim NL as const string = !"\n"
	dim SP as const string = " "
	dim QU as const string = !"\""
	dim strString as string = ""
	dim retString as string = ""
	dim currTab as uinteger = 0
	
	do
	
		char = FBSerializer.GetNextToken(stream)
		
		select case as const char
		
			case asc(!"\"")
				strString = ""
				stream.Seek(stream._SEEK_CUR, -1)
				FBSerializer.ReadJSONString(stream, @strString)
				retString &= QU & strString & QU
				continue do
				
			case asc("{")
				currTab += tabWidth
				retString &= chr(char) & NL & Space(currTab)
				
			case asc("[")
				currTab += tabWidth
				retString &= chr(char) & NL & Space(currTab)
			
			case asc(",")
				retString &= chr(char) & NL & Space(currTab)
			
			case asc("}"), asc("]")
				currTab -= tabWidth
				retString &= NL & Space(currTab) & chr(char)
			
			case asc(":")
				retString &= chr(char) & SP
				
			case 0
				exit do
				
			case else
				retString &= chr(char)
			
		end select
		
	loop while char <> 0
	
	return retString
	
end function

function JSONPrettyPrint overload ( _
		byref inJSON as string, _
		tabWidth as uinteger = 4) as string
	
	dim stream as MemoryStreamType = MemoryStreamType(StrPtr(inJSON), len(inJSON))
	return FBSerializer.JSONPrettyPrint(stream, tabWidth)
	
end function

''''''''''''''''''''JSON PARSING END''''''''''''''''''''
''''''''''''''''''''''''''''''''''''''''''''''''''''''''

'TODO: Change this to accept the FBC.FBARRAY directly
function SStaticFBArrayToBinary( _
		inPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
	
	dim elementPtr as any ptr
	dim upperBound as typeof(FBC.FBARRAYDIM.ubound)

	with inMemberInfo.FBArray
	
		'Write the array header
		dim dimensions as uinteger<32> = .Dimensions
		dim count as integer<32>
			
		FBSerializer.SerializeToBinary(@dimensions, stream)
		
		if .Dimensions > 0 then
			for dims as integer = 0 to .Dimensions - 1
				count = .dimTb(dims).ubound - .dimTb(dims).lbound
				SerializeToBinary(@count, stream)
			next
		end if
		
		'Write the array contents
		elementPtr = inPtr
		
		for dims as integer = 0 to .dimensions-1
			upperBound = .dimTb(dims).ubound - .dimTb(dims).lbound
			for i as integer = 0 to upperBound
				inMemberInfo.Serializer(elementPtr, stream)
				elementPtr += .element_len
			next
		next
		
	end with
	
	return 1
	
end function

function DStaticFBArrayFromBinary( _
		outPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
	
	dim elementPtr as any ptr

	with inMemberInfo.FBArray
	
		'Read the array header
		dim dimensions as uinteger<32>
		dim count(FBC.FB_MAXDIMENSIONS) as integer<32>
	
		FBSerializer.DeserializeFromBinary(@dimensions, stream)
		
		if dimensions <> .Dimensions then
			print "WARNING: Dimensions differ in: ";__FUNCTION__;!"\n";" got ";dimensions;" expected ";.Dimensions
		end if
		
		if dimensions > 0 then
			for dims as integer = 0 to dimensions - 1
				DeserializeFromBinary(@count(dims), stream)
			next
		end if
		
		'Read the array contents
		elementPtr = outPtr
		
		for dims as integer = 0 to dimensions-1
			for i as integer = 0 to count(dims)
				inMemberInfo.Deserializer(elementPtr, stream)
				elementPtr += .element_len
			next
		next
		
	end with
	
	return 1
	
end function

function SStaticFBArrayToJSON( _
		inPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType) as string
	
	dim retVal as string = "["
	dim elementPtr as any ptr
	dim upperBound as typeof(FBC.FBARRAYDIM.ubound)

	with inMemberInfo.FBArray

		'Write the array contents
		elementPtr = inPtr
		
		for dims as integer = 0 to .dimensions-1
		
			if .dimensions > 1 then
				retVal &= "["
			end if
			
			upperBound = .dimTb(dims).ubound - .dimTb(dims).lbound
			
			for i as integer = 0 to upperBound
			
				retVal &= inMemberInfo.ToJSON(elementPtr)
				elementPtr += .element_len
				
				if i < upperBound then
					retVal &= ","
				end if
				
			next
			
			if .dimensions > 1 then
				retVal &= "]"
			end if
			
		next
		
	end with
	
	retVal &= "]"
	
	return retVal
	
end function

function ValidateStaticFBArrayFromJSON( _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as string
	
	dim char as ubyte = 0
	dim retString as string = ""
	dim length as integer = 0
	dim upperBound as typeof(FBC.FBARRAYDIM.ubound)
	
	with inMemberInfo.FBArray
		for dims as integer = 0 to .dimensions-1
			retString = FBSerializer.GetJSONArrayLength(stream, @length)
			if len(retString) > 0 then
				'Bail on error
				exit for
			end if
			
			upperBound = .dimTb(dims).ubound - .dimTb(dims).lbound
			if length-1 > upperBound then
				'Validate bounds are within limit
				retString = "FBStatic array size outside bounds max " & upperBound & " got " & length-1
				exit for
			end if
			
			retString = FBSerializer.ReadJSONArray(stream, 0, 0, inMemberInfo.ValidateJSON)
			if len(retString) > 0 then
				exit for
			end if
			
			'Assure that multiple arrays are separated by commas
			if dims < .dimensions-1 then
				char = FBSerializer.GetNextToken(stream)
				if char <> asc(",") then
					retString = "FB static multidimentional array missing comma ,"
				end if
			end if
			
		next
	end with
	
	return retString
	
end function

function DStaticFBArrayFromJSON( _
		outPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as string

	dim char as ubyte = 0
	dim retString as string = ""
	dim length as integer = 0
	dim upperBound as typeof(FBC.FBARRAYDIM.ubound)
	
	with inMemberInfo.FBArray
		for dims as integer = 0 to .dimensions-1
			retString = FBSerializer.GetJSONArrayLength(stream, @length)
			if len(retString) > 0 then
				'Bail on error
				exit for
			end if
			
			upperBound = .dimTb(dims).ubound - .dimTb(dims).lbound
			if length-1 > upperBound then
				'Validate bounds are within limit
				retString = "FBStatic array size outside bounds max " & upperBound & " got " & length-1
				exit for
			end if
			
			retString = FBSerializer.ReadJSONArray(stream, outPtr, .element_len, inMemberInfo.FromJSON)
			if len(retString) > 0 then
				exit for
			end if
			
			'Assure that multiple arrays are separated by commas
			if dims < .dimensions-1 then
				char = FBSerializer.GetNextToken(stream)
				if char <> asc(",") then
					retString = "FB static multidimentional array missing comma ,"
				end if
			end if
			
		next
	end with
	
	return retString

end function

function GetPointerArrayElementCount( _
        byref inArrayDescriptor as const SerializerMemberInfoType.PtrArrayDescriptorType, _
        inElementCountPtr as ubyte ptr) as integer

    dim retVal as integer = 0

    'Get the size of the integer holding the array length
    select case as const inArrayDescriptor.Size
		case 0
			retVal = inArrayDescriptor.Count
        case 1
            retVal = *cast(byte ptr, inElementCountPtr)
        case 2
            retVal = *cast(short ptr, inElementCountPtr)
        case 4
            retVal = *cast(integer<32> ptr, inElementCountPtr)
        case 8
            retVal = *cast(integer<64> ptr, inElementCountPtr)
        case else
            dprint("Array element count size unexpected: ";inArrayDescriptor.Size)
			sleep
    end select

    if retVal < 0 then
        'What do we even do here?
		'This might be the result of values held in a uinteger
		'that exceed the max value of a signed integer.
		dprint("FBSerializer ERROR: Array member value was negative.")
		return -1
    end if

    return retVal

end function

'TODO: Change this to accept the element count directly
function SPtrArrayToBinary( _
		inPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
	
	dim elementPtr as any ptr
	
	dim elementCount as integer<32> = 0
	dim elementCountPtr as any ptr

	'Obtain the pointer to the start of the array 
	elementPtr = *cast(any ptr ptr, inPtr)
	
	'Obtain the pointer to the count.
	'This will not be used if the count pointer size is 0
	elementCountPtr = inPtr + inMemberInfo.PtrArray.CountPtrOffset
	
	if elementPtr then
		elementCount = GetPointerArrayElementCount(inMemberInfo.PtrArray, elementCountPtr)
	end if
	
	if elementCount < 0 then
		'Panic and bail
		return 0
	end if
	
	'Write the element count (may be 0)
	SerializeToBinary(@elementCount, stream)
	
	'Write the array contents
	for i as integer = 0 to elementCount - 1
		inMemberInfo.Serializer(elementPtr, stream)
		elementPtr += inMemberInfo.SubType.Size
	next
	
	return 1
	
end function

function DPtrArrayFromBinary( _
		outPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer

	dim elementPtr as any ptr	
	dim elementCount as integer<32>

	elementPtr = *cast(any ptr ptr, outPtr)
	
	'Check if data already exists and error
	if elementPtr <> 0 then
		dprint("Error: pointer is not null: ";elementPtr)
		sleep
	end if

	'Read in the element counts
	DeserializeFromBinary(@elementCount, stream)

	if elementCount = 0 then
		'Nothing to read in
		return 1
	end if
	
	'Call the particular allocator
	'The first argument is an unused pointer
	*cast(any ptr ptr, outPtr) = inMemberInfo.SubType.Allocator(0, elementCount)
	
	'The element ptr must be re-obtained
	elementPtr = *cast(any ptr ptr, outPtr)
	
	'Read in the array contents
	for i as integer = 0 to elementCount - 1
		inMemberInfo.Deserializer(elementPtr, stream)
		elementPtr += inMemberInfo.SubType.Size
	next
	
	return 1
	
end function

function SPtrArrayToJSON( _
		inPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType) as string

	dim retVal as string = "["
	dim elementPtr as any ptr
	
	dim elementCount as integer<32> = 0
	dim elementCountPtr as any ptr

	'Obtain the pointer to the start of the array 
	elementPtr = *cast(any ptr ptr, inPtr)
	
	'Obtain the pointer to the count.
	'This will not be used if the count pointer size is 0
	elementCountPtr = inPtr + inMemberInfo.PtrArray.CountPtrOffset
	
	if elementPtr then
		elementCount = GetPointerArrayElementCount(inMemberInfo.PtrArray, elementCountPtr)
	end if
	
	if elementCount < 0 then
		'Panic and bail
		return retVal & "SPtrArrayToJSON ERROR"
	end if
	
	'Append the array contents
	for i as integer = 0 to elementCount - 1
	
		retVal &= inMemberInfo.ToJSON(elementPtr)
		elementPtr += inMemberInfo.SubType.Size
		
		if i < elementCount-1 then
			retVal &= ","
		end if
		
	next
	
	retVal &= "]"
	
	return retVal

end function

function ValidatePtrArrayFromJSON( _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as string
	
	return FBSerializer.ReadJSONArray(stream, 0, 0, inMemberInfo.ValidateJSON)

end function

function DPtrArrayFromJSON( _
		outPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as string

	dim elementPtr as any ptr
	dim char as ubyte = 0
	dim retString as string = ""
	dim length as integer = 0
	
	elementPtr = *cast(any ptr ptr, outPtr)
	
	'Check if data already exists and error
	if elementPtr <> 0 then
		dprint("Error: pointer is not null: ";elementPtr)
		sleep
	end if
	
	retString = FBSerializer.GetJSONArrayLength(stream, @length)
	
	if len(retString) > 0 then
		'Bail on error
		return retString
	end if
	
	if length = 0 then
		'Empty array
		return ""
	end if
	
	'Call the allocator
	*cast(any ptr ptr, outPtr) = inMemberInfo.SubType.Allocator(0, length)
	
	elementPtr = *cast(any ptr ptr, outPtr)
	
	retString = FBSerializer.ReadJSONArray( _
		stream, _
		elementPtr, _
		inMemberInfo.SubType.Size, _
		inMemberInfo.FromJSON)
	
	return retString

end function

function SPointerToBinary( _
		inPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
	
	dim elementPtr as any ptr
	dim nullFlag as ubyte = 0
	
	'Obtain the pointer to the any ptr variant of the SerializeToBinary function
	'This will determine if the underlying type is a pointer (not yet handled)
	dim edgeCase as sub(as any ptr, byref stream as StreamInterface)
	edgeCase = cast(typeof(edgeCase), ProcPtr(SerializeToBinary, sub(as any ptr, byref stream as StreamInterface)))
	
	elementPtr = *cast(any ptr ptr, inPtr)
	
	if elementPtr = 0 then
		'Write a single 0 byte indicating that the pointer was null
		SerializeToBinary(@nullFlag, stream)
		return 1
	end if
	
	'Write out a flag indicating that the pointer is not null
	nullFlag = &hff
	SerializeToBinary(@nullFlag, stream)
	
	if inMemberInfo.Serializer = edgeCase then
		print "Hit edge case in: ";__FUNCTION__
		return 0
	end if
	
	inMemberInfo.Serializer(elementPtr, stream)
	
	return 1

end function

function DPointerFromBinary( _
		outPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
	
	dim elementPtr as any ptr
	dim nullFlag as ubyte	
	
	'Read a byte that checks if the pointer was serialized or not
	DeserializeFromBinary(@nullFlag, stream)
	
	if nullFlag = 0 then
		return 1
	end if
	
	'Call the particular allocator
	'The first argument is an unused pointer
	*cast(any ptr ptr, outPtr) = inMemberInfo.SubType.Allocator(0, 1)
	
	'The element ptr must be re-obtained
	elementPtr = *cast(any ptr ptr, outPtr)

	inMemberInfo.Deserializer(elementPtr, stream)
	
	return 1

end function

function SPointerToJSON( _
		inPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType) as string
	
	dim retVal as string
	dim elementPtr as any ptr
	
	'Obtain the pointer to the any ptr variant of the SerializeToBinary function
	'This will determine if the underlying type is a pointer (not yet handled)
	dim edgeCase as sub(as any ptr, byref stream as StreamInterface)
	edgeCase = cast(typeof(edgeCase), ProcPtr(SerializeToBinary, sub(as any ptr, byref stream as StreamInterface)))
	
	elementPtr = *cast(any ptr ptr, inPtr)
	
	if elementPtr = 0 then
		return "null"
	end if
	
	if inMemberInfo.Serializer = edgeCase then
		print "Hit edge case in: ";__FUNCTION__
		sleep
		return retVal & "SPointerToJSON ERROR"
	end if
	
	retVal &= inMemberInfo.ToJSON(elementPtr)
	
	return retVal
	
end function

function ValidatePointerFromJSON( _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as string

	dim char as ubyte = 0
	dim retString as string = ""
	
	'Peek at the first character
	char = FBSerializer.GetNextToken(stream)
	stream.Seek(stream._SEEK_CUR, -1)
	
	if char = asc("n") then
		retString = FBSerializer.ReadJSONNull(stream)
	else
		retString = inMemberInfo.ValidateJSON(0, stream)
	end if
	
	return retString
	
end function

function DPointerFromJSON( _
		outPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as string

	dim elementPtr as any ptr
	dim char as ubyte = 0
	dim retString as string = ""
	
	elementPtr = *cast(any ptr ptr, outPtr)
	
	'Check if pointer already exists and error
	if elementPtr <> 0 then
		dprint("Error: pointer is not null: ";elementPtr)
		sleep
	end if
	
	'Peek at the first character
	char = FBSerializer.GetNextToken(stream)
	stream.Seek(stream._SEEK_CUR, -1)
	
	if char = asc("n") then
		retString = FBSerializer.ReadJSONNull(stream)
		if len(retString) = 0 then
			*cast(any ptr ptr, outPtr) = 0
		end if
	else	
		'Call the particular allocator
		'The first argument is an unused pointer
		*cast(any ptr ptr, outPtr) = inMemberInfo.SubType.Allocator(0, 1)
		elementPtr = *cast(any ptr ptr, outPtr)
		
		retString = inMemberInfo.FromJSON(elementPtr, stream)
	end if
	
	if len(retString) > 0 then
		'Augment the error response to specify null or object
		retString = !"Deserializing pointer must be 'null' or object {}\n" & retString
	end if
	
	return retString

end function

function SUnionToBinary( _
		inPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
	
	'The compiler stops you from putting non-blittable data
	'into a union so this should be fine
	stream.Write(inPtr, inMemberInfo.BaseType.Size)
	
	return 1
	
end function

function DUnionFromBinary( _
		outPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
	
	stream.Read(outPtr, inMemberInfo.BaseType.Size)
	
	return 1
	
end function

function SUnionToJSON( _
		inPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType) as string

	dim retVal as string = "["
	dim bytePtr as ubyte ptr
	
	bytePtr = cast(ubyte ptr, inPtr)
	
	'TODO: Base64 is certainly a better choice here
	for i as integer = 0 to inMemberInfo.BaseType.Size - 1
		retVal &= SerializeToJSON(bytePtr)
		bytePtr += 1

		if i < inMemberInfo.BaseType.Size - 1 then
			retVal &= ","
		end if
	next
	
	retVal &= "]"
	return retVal

end function

function ValidateUnionFromJSON( _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as string
	
	dim retString as string = ""
	dim length as integer = 0
	
	retString = FBSerializer.GetJSONArrayLength(stream, @length)
	if len(retString) then
		return retString
	end if
	
	if length > inMemberInfo.BaseType.Size then
		retString = "Union array length is too large expected " & inMemberInfo.BaseType.Size & " got " & length
		return retString
	end if
	
	FBSerializer.ReadJSONArray(stream, 0, 0, FBSerializer.GetValidateJSON(cast(ubyte ptr, 0)))
	
	return retString
	
end function

function DUnionFromJSON( _
		outPtr as any ptr, _
		byref inMemberInfo as const SerializerMemberInfoType, _
		byref stream as StreamInterface) as string
	
	dim retString as string = ""
	dim length as integer = 0
	
	retString = FBSerializer.GetJSONArrayLength(stream, @length)
	if len(retString) then
		return retString
	end if
	
	if length > inMemberInfo.BaseType.Size then
		retString = "Union array length is too large expected " & inMemberInfo.BaseType.Size & " got " & length
		return retString
	end if
	
	FBSerializer.ReadJSONArray( _
		stream, _
		outPtr, _
		1, _
		FBSerializer.GetDeserializeFromJSON(cast(ubyte ptr, 0)))
	
	return retString
	
end function

function SToBinary( _
		inStruct as any ptr, _
		serializerArray() as const FBSerializer.SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer

	dim memberPtr as any ptr
	dim retVal as integer
	
	for i as integer = 0 to ubound(serializerArray)

		with serializerArray(i)
			
			memberPtr = inStruct + .BaseType.Offset
			
			select case as const .BaseType._Type
			
				case SerializerMemberInfoType._STATIC_FB_ARRAY 'Freebasic built-in array type (array(...))
					retVal = SStaticFBArrayToBinary(memberPtr, serializerArray(i), stream)
				case SerializerMemberInfoType._DYNAMIC_FB_ARRAY 
					'TODO: implement
				case SerializerMemberInfoType._PTR_ARRAY       'Pointer representing an array
					retVal = SPtrArrayToBinary(memberPtr, serializerArray(i), stream)
				case SerializerMemberInfoType._POINTER         'Any other pointer type
					retVal = SPointerToBinary(memberPtr, serializerArray(i), stream)
				case SerializerMemberInfoType._UNION           'A union type
					retVal = SUnionToBinary(memberPtr, serializerArray(i), stream)
				case SerializerMemberInfoType._FIXED_STRING    '*sigh* special casing bullshit
					SerializeToBinary(cast(zstring ptr, memberPtr), stream)
					retVal = 1
				case else
					.Serializer(memberPtr, stream)
					retVal = 1
					
			end select
			
			if retVal = 0 then
				dprint("FBSerializer ERROR: encountered error serializing member: ";*.BaseName;" to binary")
			end if
			
		end with
	next
	
	return 1

end function

function DFromBinary( _
		outStruct as any ptr, _
		serializerArray() as const FBSerializer.SerializerMemberInfoType, _
		byref stream as StreamInterface) as integer
	
	dim memberPtr as any ptr
	dim retVal as integer
	
	for i as integer = 0 to ubound(serializerArray)
		
		with serializerArray(i)
		
			memberPtr = outStruct + .BaseType.Offset
			
			if stream.GetError() then
				print "DFromBinary ERROR: Stream error code hit unexpectedly: ";stream.GetError()
				sleep
				return 0
			end if
			
			select case as const .BaseType._Type
				case SerializerMemberInfoType._STATIC_FB_ARRAY 'Freebasic built-in array type (array(...))
					retVal = DStaticFBArrayFromBinary(memberPtr, serializerArray(i), stream)
				case SerializerMemberInfoType._DYNAMIC_FB_ARRAY
					'TODO: figure out how to implement
				case SerializerMemberInfoType._PTR_ARRAY       'Pointer representing an array
					retVal = DPtrArrayFromBinary(memberPtr, serializerArray(i), stream)
				case SerializerMemberInfoType._POINTER         'Any other pointer type
					retVal = DPointerFromBinary(memberPtr, serializerArray(i), stream)
				case SerializerMemberInfoType._UNION           'Any named union type
					retVal = DUnionFromBinary(memberPtr, serializerArray(i), stream)
				case SerializerMemberInfoType._FIXED_STRING    'Petition to remove string * n type from the language...
					DeserializeFromBinary(cast(zstring ptr, memberPtr), stream)
					retVal = 1
				case else
					.Deserializer(memberPtr, stream)
					retVal = 1
			end select
			
			if retVal = 0 then
				dprint("FBSerializer ERROR: encountered error deserializing member: ";*.BaseName;" to binary")
			end if
			
		end with
	next
	
	return 1
	
end function

'TODO: Make a wstring variant
function SToJSON( _
		inStruct as any ptr, _
		serializerArray() as const FBSerializer.SerializerMemberInfoType) as string
	
	dim retVal as string = "{"
	
	dim memberPtr as any ptr
	
	var upperBound = ubound(serializerArray)
	
	for i as integer = 0 to upperBound
		
		with serializerArray(i)
			
			retVal &= !"\"" & *.BaseName & !"\":"
			
			memberPtr = inStruct + .BaseType.Offset
			
			select case as const .BaseType._Type
				case SerializerMemberInfoType._STATIC_FB_ARRAY 'Freebasic built-in array type (array(...))
					retVal &= SStaticFBArrayToJSON(memberPtr, serializerArray(i))
				case SerializerMemberInfoType._DYNAMIC_FB_ARRAY
					'TODO: implement
				case SerializerMemberInfoType._PTR_ARRAY       'Pointer representing an array
					retVal &= SPtrArrayToJSON(memberPtr, serializerArray(i))
				case SerializerMemberInfoType._POINTER         'Any other pointer type
					retVal &= SPointerToJSON(memberPtr, serializerArray(i))
				case SerializerMemberInfoType._UNION           'Any named union type
					retVal &= SUnionToJSON(memberPtr, serializerArray(i))
				case SerializerMemberInfoType._FIXED_STRING    'Special casing for the window licking type...
					retVal &= SerializeToJSON(cast(zstring ptr, memberPtr))
				case else
					retVal &= .ToJson(memberPtr)
			end select
			
			if i < upperBound then
				retVal &= ","
			end if
			
		end with
	next
	
	return retVal & "}"
	
end function

function VFromJSON( _
		serializerArray() as const FBSerializer.SerializerMemberInfoType, _
		byref stream as StreamInterface) as string
	
	dim char as ubyte = 0
	dim retString as string = ""
	
	dim readState as ubyte = 0
	dim key as string = ""
	dim hasValue as ubyte = 0
	
	dim foundKey as ubyte
	
	char = FBSerializer.GetNextToken(stream)
	if char <> asc("{") then
		return "Expected '{' got " & chr(char)
	end if
	
	do
		
		retString = FBSerializer.GetNextJSONKeyValue(stream, readState, @key, @hasValue)
		
		if hasValue = 0 then
			exit do
		end if
		
		for i as integer = 0 to ubound(serializerArray)
			'Search for the key in the object
			with serializerArray(i)
				if lcase(*.BaseName) = lcase(key) then
					
					foundKey = 1
					
					select case as const .BaseType._Type
						case SerializerMemberInfoType._STATIC_FB_ARRAY 'Freebasic built-in array type (array(...))
							retString = ValidateStaticFBArrayFromJSON(serializerArray(i), stream)
						case SerializerMemberInfoType._DYNAMIC_FB_ARRAY
							'TODO: figure out how to implement
						case SerializerMemberInfoType._PTR_ARRAY       'Pointer representing an array
							retString = ValidatePtrArrayFromJSON(serializerArray(i), stream)
						case SerializerMemberInfoType._POINTER         'Any other pointer type
							retString = ValidatePointerFromJSON(serializerArray(i), stream)
						case SerializerMemberInfoType._UNION           'Any named union type
							retString = ValidateUnionFromJSON(serializerArray(i), stream)
						case SerializerMemberInfoType._FIXED_STRING    'It's still bad
							retString = ValidateJSON(cast(zstring ptr, 0), stream)
						case else
							retString = .ValidateJSON(0, stream)
					end select
					
					'Set the read token to expect a comma or end of object
					exit for
					
				end if
			end with
		next
			
		if foundKey = 0 then
			'Key was not in the object, this is an error
			retString = "Unexpected key in object '" & key & "'"
		end if
		
	loop while len(retString) = 0
	
	return retString
	
end function

function DFromJSON( _
		outStruct as any ptr, _
		serializerArray() as const FBSerializer.SerializerMemberInfoType, _
		byref stream as StreamInterface) as string
	
	dim memberPtr as any ptr
	dim char as ubyte = 0
	dim retString as string = ""

	dim readState as ubyte
	dim key as string = ""
	dim hasValue as ubyte = 0
	
	dim foundKey as ubyte
	
	char = FBSerializer.GetNextToken(stream)
	if char <> asc("{") then
		return "Expected '{' got " & chr(char)
	end if
	
	do
		
		retString = FBSerializer.GetNextJSONKeyValue(stream, readState, @key, @hasValue)
		
		if hasValue = 0 then
			exit do
		end if
		
		for i as integer = 0 to ubound(serializerArray)
			'Search for the key in the object
			with serializerArray(i)
				if lcase(*.BaseName) = lcase(key) then
					
					foundKey = 1
					
					memberPtr = outStruct + .BaseType.Offset
					
					select case as const .BaseType._Type
						case SerializerMemberInfoType._STATIC_FB_ARRAY 'Freebasic built-in array type (array(...))
							retString = DStaticFBArrayFromJSON(memberPtr, serializerArray(i), stream)
						case SerializerMemberInfoType._DYNAMIC_FB_ARRAY
							'TODO: figure out how to implement
						case SerializerMemberInfoType._PTR_ARRAY       'Pointer representing an array
							retString = DPtrArrayFromJSON(memberPtr, serializerArray(i), stream)
						case SerializerMemberInfoType._POINTER         'Any other pointer type
							retString = DPointerFromJSON(memberPtr, serializerArray(i), stream)
						case SerializerMemberInfoType._UNION           'Any named union type
							retString = DUnionFromJSON(memberPtr, serializerArray(i), stream)
						case SerializerMemberInfoType._FIXED_STRING    ':clown_face:
							retString = DeserializeFromJSON(cast(zstring ptr, memberPtr), stream)
						case else
							retString = .FromJSON(memberPtr, stream)
					end select
					
					'Set the read token to expect a comma or end of object
					exit for
					
				end if
			end with
		next
				
		if foundKey = 0 then
			'Key was not in the object, this is an error
			retString = "Unexpected key in object '" & key & "'"
		end if
		
	loop while len(retString) = 0
	
	return retString
	
end function

'Macros cleaned up at end of file

'Due to what I believe is a bug, ProcPtr does not fully coerce types that are
'set through typeof(variable).  So to get around that, I shuttle access
'of the serializer functions through this function that explicitly sets the type
'that's passed to ProcPtr
#macro CreateSGet(__TYPE)
function GetSerializeToBinary overload (inVal as __TYPE ptr) as sub(as any ptr, byref stream as StreamInterface)
	return cast(sub(as any ptr, byref stream as StreamInterface), _
		_ 'Note that it uses __TYPE directly instead of typeof()
		procptr(FBSerializer.SerializeToBinary, sub(as __TYPE ptr, byref stream as StreamInterface)))
end function
#endmacro

'Same thing, but for deserialization
#macro CreateDGet(__TYPE)
function GetDeserializeFromBinary overload (inVal as __TYPE ptr) as sub(as any ptr, byref stream as StreamInterface)
	return cast(sub(as any ptr, byref stream as StreamInterface), _
		_ 'Note that it uses __TYPE directly instead of typeof()
		procptr(FBSerializer.DeserializeFromBinary, sub(as __TYPE ptr, byref stream as StreamInterface)))
end function
#endmacro

#macro CreateSJSONGet(__TYPE)
function GetSerializeToJSON overload (inVal as __TYPE ptr) as function(as any ptr) as string
	return cast(function(as any ptr) as string, _
		procptr(FBSerializer.SerializeToJSON, function(as __TYPE ptr) as string))
end function
#endmacro

#macro CreateVJSONGet(__TYPE)
function GetValidateJSON overload (inVal as __TYPE ptr) as function(as any ptr, byref stream as StreamInterface) as string
	return cast(function(as any ptr, byref stream as StreamInterface) as string, _
		procptr(FBSerializer.ValidateJSON, function(as __TYPE ptr, byref stream as StreamInterface) as string))
end function
#endmacro

#macro CreateDJSONGet(__TYPE)
function GetDeserializeFromJSON overload (inVal as __TYPE ptr) as function(as any ptr, byref stream as StreamInterface) as string
	return cast(function(as any ptr, byref stream as StreamInterface) as string, _
		procptr(FBSerializer.DeserializeFromJSON, function(as __TYPE ptr, byref stream as StreamInterface) as string))
end function
#endmacro

#macro CreateGetters(__TYPE)
	CreateSGet(__TYPE)
	CreateDGet(__TYPE)
	CreateSJSONGet(__TYPE)
	CreateVJSONGet(__TYPE)
	CreateDJSONGet(__TYPE)

	function TypeAllocator overload (unused as __TYPE ptr, inCount as integer) as any ptr
		return new __TYPE
	end function
	
	function GetTypeAllocator overload (inVal as __TYPE ptr) as function(as any ptr, as integer) as any ptr
		return cast(function(as any ptr, as integer) as any ptr, _
			procptr(FBSerializer.TypeAllocator, function(as __TYPE ptr, as integer) as any ptr))
	end function

	function TypeArrayAllocator overload (unused as __TYPE ptr, inCount as integer) as any ptr
		return new __TYPE[inCount]
	end function
	
	function GetTypeArrayAllocator overload (inVal as __TYPE ptr) as function(as any ptr, as integer) as any ptr
		return cast(function(as any ptr, as integer) as any ptr, _
			procptr(FBSerializer.TypeArrayAllocator, function(as __TYPE ptr, as integer) as any ptr))
	end function
	
#endmacro

'Boolean
sub SerializeToBinary overload (inBool as boolean ptr, byref stream as StreamInterface)
	stream.Write(inBool, sizeof(*inBool))
end sub

sub DeserializeFromBinary overload (inBool as boolean ptr, byref stream as StreamInterface)
	stream.Read(inBool, sizeof(*inBool))
end sub

function SerializeToJSON overload (inBool as boolean ptr) as string
	return iif(*inBool, "true", "false")
end function

function ValidateJSON overload (inBool as boolean ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONBoolean(stream)
end function

function DeserializeFromJSON overload (inBool as boolean ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONBoolean(stream, inBool)
end function

CreateGetters(boolean)

'Byte
sub SerializeToBinary overload (inByte as byte ptr, byref stream as StreamInterface)
	stream.Write(inByte, sizeof(*inByte))
end sub

sub DeserializeFromBinary overload (inByte as byte ptr, byref stream as StreamInterface)
	stream.Read(inByte, sizeof(*inByte))
end sub

function SerializeToJSON overload (inByte as byte ptr) as string
	return Str(*inByte)
end function

function ValidateJSON overload (inByte as byte ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inByte as byte ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inByte = cast(typeof(*inByte), retDouble)
	return retString
end function

CreateGetters(byte)

sub SerializeToBinary overload (inUByte as ubyte ptr, byref stream as StreamInterface)
	stream.Write(inUByte, sizeof(*inUByte))
end sub

sub DeserializeFromBinary overload (inUByte as ubyte ptr, byref stream as StreamInterface)
	stream.Read(inUByte, sizeof(*inUByte))
end sub

function SerializeToJSON overload (inUByte as ubyte ptr) as string
	return Str(*inUByte)
end function

function ValidateJSON overload (inUByte as ubyte ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inUByte as ubyte ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inUByte = cast(typeof(*inUByte), retDouble)
	return retString
end function

CreateGetters(ubyte)

'Short
sub SerializeToBinary overload (inShort as short ptr, byref stream as StreamInterface)
	stream.Write(inShort, sizeof(*inShort))
end sub

sub DeserializeFromBinary overload (inShort as short ptr, byref stream as StreamInterface)
	stream.Read(inShort, sizeof(*inShort))
end sub

function SerializeToJSON overload (inShort as short ptr) as string
	return Str(*inShort)
end function

function ValidateJSON overload (inShort as short ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inShort as short ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inShort = cast(typeof(*inShort), retDouble)
	return retString
end function

CreateGetters(short)

sub SerializeToBinary overload (inUShort as ushort ptr, byref stream as StreamInterface)
	stream.Write(inUShort, sizeof(*inUShort))
end sub

sub DeserializeFromBinary overload (inUShort as ushort ptr, byref stream as StreamInterface)
	stream.Read(inUShort, sizeof(*inUShort))
end sub

function SerializeToJSON overload (inUShort as ushort ptr) as string
	return Str(*inUShort)
end function

function ValidateJSON overload (inUShort as ushort ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inUShort as ushort ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inUShort = cast(typeof(*inUShort), retDouble)
	return retString
end function

CreateGetters(ushort)

'Integer<32>
sub SerializeToBinary overload (inInt as integer<32> ptr, byref stream as StreamInterface)
	stream.Write(inInt, sizeof(*inInt))
end sub

sub DeserializeFromBinary overload (inInt as integer<32> ptr, byref stream as StreamInterface)
	stream.Read(inInt, sizeof(*inInt))
end sub

function SerializeToJSON overload (inInt as integer<32> ptr) as string
	return Str(*inInt)
end function

function ValidateJSON overload (inInt as integer<32> ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inInt as integer<32> ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inInt = cast(typeof(*inInt), retDouble)
	return retString
end function

CreateGetters(integer<32>)

sub SerializeToBinary overload (inUInt as uinteger<32> ptr, byref stream as StreamInterface)
	stream.Write(inUInt, sizeof(*inUInt))
end sub

sub DeserializeFromBinary overload (inUInt as uinteger<32> ptr, byref stream as StreamInterface)
	stream.Read(inUInt, sizeof(*inUInt))
end sub

function SerializeToJSON overload (inUInt as uinteger<32> ptr) as string
	return Str(*inUInt)
end function

function ValidateJSON overload (inUInt as uinteger<32> ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inUInt as uinteger<32> ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inUInt = cast(typeof(*inUInt), retDouble)
	return retString
end function

CreateGetters(uinteger<32>)

'Integer<64>
sub SerializeToBinary overload (inInt as integer<64> ptr, byref stream as StreamInterface)
	stream.Write(inInt, sizeof(*inInt))
end sub

sub DeserializeFromBinary overload (inInt as integer<64> ptr, byref stream as StreamInterface)
	stream.Read(inInt, sizeof(*inInt))
end sub

function SerializeToJSON overload (inInt as integer<64> ptr) as string
	return Str(*inInt)
end function

function ValidateJSON overload (inInt as integer<64> ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inInt as integer<64> ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inInt = cast(typeof(*inInt), retDouble)
	return retString
end function

CreateGetters(integer<64>)

sub SerializeToBinary overload (inUInt as uinteger<64> ptr, byref stream as StreamInterface)
	stream.Write(inUInt, sizeof(*inUInt))
end sub

sub DeserializeFromBinary overload (inUInt as uinteger<64> ptr, byref stream as StreamInterface)
	stream.Read(inUInt, sizeof(*inUInt))
end sub

function SerializeToJSON overload (inUInt as uinteger<64> ptr) as string
	return Str(*inUInt)
end function

function ValidateJSON overload (inUInt as uinteger<64> ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inUInt as uinteger<64> ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inUInt = cast(typeof(*inUInt), retDouble)
	return retString
end function

CreateGetters(uinteger<64>)

'Architecture dependent Integer
sub SerializeToBinary overload (inInt as integer ptr, byref stream as StreamInterface)
	stream.Write(inInt, sizeof(*inInt))
end sub

sub DeserializeFromBinary overload (inInt as integer ptr, byref stream as StreamInterface)
	stream.Read(inInt, sizeof(*inInt))
end sub

function SerializeToJSON overload (inInt as integer ptr) as string
	return Str(*inInt)
end function

function ValidateJSON overload (inInt as integer ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inInt as integer ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inInt = cast(typeof(*inInt), retDouble)
	return retString
end function

CreateGetters(integer)

sub SerializeToBinary overload (inUInt as uinteger ptr, byref stream as StreamInterface)
	stream.Write(inUInt, sizeof(*inUInt))
end sub

sub DeserializeFromBinary overload (inUInt as uinteger ptr, byref stream as StreamInterface)
	stream.Read(inUInt, sizeof(*inUInt))
end sub

function SerializeToJSON overload (inUInt as uinteger ptr) as string
	return Str(*inUInt)
end function

function ValidateJSON overload (inUInt as uinteger ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inUInt as uinteger ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inUInt = cast(typeof(*inUInt), retDouble)
	return retString
end function

CreateGetters(uinteger)

'Single
sub SerializeToBinary overload (inSingle as single ptr, byref stream as StreamInterface)
	stream.Write(inSingle, sizeof(*inSingle))
end sub

sub DeserializeFromBinary overload (inSingle as single ptr, byref stream as StreamInterface)
	stream.Read(inSingle, sizeof(*inSingle))
end sub

function SerializeToJSON overload (inSingle as single ptr) as string
	return Str(*inSingle)
end function

function ValidateJSON overload (inSingle as single ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inSingle as single ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inSingle = cast(typeof(*inSingle), retDouble)
	return retString
end function

CreateGetters(single)

'Double
sub SerializeToBinary overload (inDouble as double ptr, byref stream as StreamInterface)
	stream.Write(inDouble, sizeof(*inDouble))
end sub

sub DeserializeFromBinary overload (inDouble as double ptr, byref stream as StreamInterface)
	stream.Read(inDouble, sizeof(*inDouble))
end sub

function SerializeToJSON overload (inDouble as double ptr) as string
	return Str(*inDouble)
end function

function ValidateJSON overload (inDouble as double ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONNumber(stream)
end function

function DeserializeFromJSON overload (inDouble as double ptr, byref stream as StreamInterface) as string
	dim retDouble as double
	dim retString as string = ""
	retString = FBSerializer.ReadJSONNumber(stream, @retDouble)
	*inDouble = cast(typeof(*inDouble), retDouble)
	return retString
end function

CreateGetters(double)

'String
sub SerializeToBinary overload (inString as string ptr, byref stream as StreamInterface)
	dim stringLen as integer<32> = len(*inString)
	stream.Write(@stringLen, sizeof(stringLen))
	if stringLen > 0 then
		stream.Write(StrPtr(*inString), stringLen+1) '+1 to include the null terminator
	end if
end sub

sub DeserializeFromBinary overload (inString as string ptr, byref stream as StreamInterface)
	dim stringLen as integer<32>
	stream.Read(@stringLen, sizeof(stringLen))
	if stringLen > 0 then
		*inString = String(stringLen, !"\0") 'Allocate enough space for the string
		stream.Read(StrPtr(*inString), stringLen+1) '+1 as we wrote the null terminator
	end if
end sub

function SerializeToJSON overload (inString as string ptr) as string
	return !"\"" & *inString & !"\""
end function

function ValidateJSON overload (inString as string ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONString(stream)
end function

function DeserializeFromJSON overload (inString as string ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONString(stream, inString)
end function

CreateGetters(string)

'ZString
sub SerializeToBinary overload (inZStringPtr as zstring ptr, byref stream as StreamInterface)
	dim stringLen as integer<32> = len(*inZStringPtr)
	stream.Write(@stringLen, sizeof(stringLen))
	if stringLen > 0 then
		stream.Write(inZStringPtr, stringLen) 'No +1 as the null terminator is included in the fixed zstring length
	end if
end sub

sub DeserializeFromBinary overload (inZStringPtr as zstring ptr, byref stream as StreamInterface)
	dim stringLen as integer<32>
	stream.Read(@stringLen, sizeof(stringLen))
	if stringLen > 0 then
		stream.Read(inZStringPtr, stringLen)
	end if
end sub

function SerializeToJSON overload (inZString as zstring ptr) as string
	return !"\"" & *inZString & !"\""
end function

function ValidateJSON overload (inZString as zstring ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONString(stream)
end function

function DeserializeFromJSON overload (inZString as zstring ptr, byref stream as StreamInterface) as string
	dim retString as string = ""
	dim tmpString as string = ""
	retString = FBSerializer.ReadJSONString(stream, @tmpString)
	*inZString = tmpString
	return retString
end function

'Fixed length zstrings cannot be dynamically allocated
CreateSGet(zstring)
CreateDGet(zstring)
CreateSJSONGet(zstring)
CreateVJSONGet(zstring)
CreateDJSONGet(zstring)

sub SerializeToBinary overload (inZStringPtr as zstring ptr ptr, byref stream as StreamInterface)
	SerializeToBinary(*inZStringPtr, stream)
end sub

sub DeserializeFromBinary overload (inZStringPtr as zstring ptr ptr, byref stream as StreamInterface)
	'Deserializing to a zstring ptr assumes that this was dynamically allocated
	dim stringLen as integer<32>
	stream.Read(@stringLen, sizeof(stringLen))
	if stringLen > 0 then
		*inZStringPtr = callocate(stringLen+1, sizeof(ubyte)) '+1 for null terminator
		stream.Read(*inZStringPtr, stringLen)
	end if
end sub

function SerializeToJSON overload (inZStringPtr as zstring ptr ptr) as string
	return SerializeToJSON(*inZStringPtr)
end function

function ValidateJSON overload (inZStringPtr as zstring ptr ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONString(stream)
end function

function DeserializeFromJSON overload (inZStringPtr as zstring ptr ptr, byref stream as StreamInterface) as string
	dim retString as string = ""
	dim tmpString as string = ""
	retString = FBSerializer.ReadJSONString(stream, @tmpString)
	if len(tmpString) > 0 then
		*inZStringPtr = callocate(len(tmpString)+1, sizeof(ubyte)) '+1 for null terminator
		**inZStringPtr = tmpString
	end if
	return retString
end function

CreateGetters(zstring ptr)

'WString
sub SerializeToBinary overload (inWStringPtr as wstring ptr, byref stream as StreamInterface)
	dim stringLen as integer<32> = len(*inWStringPtr)
	dim dataSize as integer<32> = sizeof(wstring)
	stream.Write(@stringLen, sizeof(stringLen))
	stream.Write(@dataSize, sizeof(dataSize))
	if stringLen > 0 then
		stream.Write(inWStringPtr, stringLen*dataSize)
	end if
end sub

sub DeserializeFromBinary overload (inWStringPtr as wstring ptr, byref stream as StreamInterface)
	'TODO: Handle a situation where the dataSize does not match current system
	dim stringLen as integer<32>
	dim dataSize as integer<32>
	stream.Read(@stringLen, sizeof(stringLen))
	stream.Read(@dataSize, sizeof(dataSize))
	if stringLen > 0 then
		stream.Read(inWStringPtr, stringLen*dataSize)
	end if
end sub

'TODO: This really ought to return a wstring
'It makes little sense to serialize a wstring into a string
'unless it's guaranteed that the wstring is only holding ascii
function SerializeToJSON overload (inWString as wstring ptr) as string
	return !"\"" & *inWString & !"\""
end function

function ValidateJSON overload (inWString as wstring ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONString(stream)
end function

function DeserializeFromJSON overload (inWString as wstring ptr, byref stream as StreamInterface) as string
	dim retString as string = ""
	dim tmpString as string = ""
	retString = FBSerializer.ReadJSONString(stream, @tmpString)
	*inWString = wstr(tmpString)
	return retString
end function

'Fixed length wstrings cannot be dynamically allocated
CreateSGet(wstring)
CreateDGet(wstring)
CreateSJSONGet(wstring)
CreateVJSONGet(wstring)
CreateDJSONGet(wstring)

sub SerializeToBinary overload (inWStringPtr as wstring ptr ptr, byref stream as StreamInterface)
	SerializeToBinary(*inWStringPtr, stream)
end sub

sub DeserializeFromBinary overload (inWStringPtr as wstring ptr ptr, byref stream as StreamInterface)
	dim stringLen as integer<32>
	dim dataSize as integer<32>
	stream.Read(@stringLen, sizeof(stringLen))
	stream.Read(@dataSize, sizeof(dataSize))
	if stringLen > 0 then
		*inWStringPtr = callocate((stringLen+1), dataSize)
		stream.Read(*inWStringPtr, stringLen * dataSize)
	end if
end sub

function SerializeToJSON overload (inWStringPtr as wstring ptr ptr) as string
	return SerializeToJSON(*inWStringPtr)
end function

function ValidateJSON overload (inWStringPtr as wstring ptr ptr, byref stream as StreamInterface) as string
	return FBSerializer.ReadJSONString(stream)
end function

function DeserializeFromJSON overload (inWStringPtr as wstring ptr ptr, byref stream as StreamInterface) as string
	dim retString as string = ""
	dim tmpString as string = ""
	retString = FBSerializer.ReadJSONString(stream, @tmpString)
	if len(tmpString) > 0 then
		*inWStringPtr = callocate(len(tmpString)+1, sizeof(wstring)) '+1 for null terminator
		**inWStringPtr = wstr(tmpString)
	end if
	return retString
end function

CreateGetters(wstring ptr)

'The catch all for any type of pointer.
'This should never be called and if you
'see this warning you did something wrong.
sub SerializeToBinary overload (inPtr as any ptr, byref stream as StreamInterface)
	dprint("Serialize any ptr error")
end sub
CreateSGet(any)

'Same as above
sub DeserializeFromBinary overload (inPtr as any ptr, byref stream as StreamInterface)
	dprint("Deserialize any ptr error")
end sub
CreateDGet(any)

'Same as above
function SerializeToJSON overload (inPtr as any ptr) as string
	return "SerializeToJSON any ptr error"
end function
CreateSJSONGet(any)

function ValidateJSON overload (inPtr as any ptr, byref stream as StreamInterface) as string
	return "ValidateJSON any ptr error"
end function
CreateVJSONGet(any)

function DeserializeFromJSON overload (inPtr as any ptr, byref stream as StreamInterface) as string
	return "DeserializeFromJSON any ptr error"
end function
CreateDJSONGet(any)

#undef CreateSGet
#undef CreateDGet
#undef CreateSJSONGet
#undef CreateGetters

end namespace

''''''''''''''''''''''''''''''EXAMPLES''''''''''''''''''''''''''''''
/'
type MiniUDT
	dim s as string
end type

CREATE_SERIALIZER(MiniUDT, _
	MEMBER_SIMPLE(s))

type SimpleUDT

	dim bool as boolean
	dim i8 as byte
	dim u8 as ubyte
	dim i16 as short
	dim u16 as ushort
	dim i32 as integer<32>
	dim u32 as uinteger<32>
	dim l as long
	dim ul as ulong
	dim i64 as integer<64>
	dim u64 as uinteger<64>
	dim li as longint
	dim uli as ulongint
	
	dim f as single ' "f" is for "fsingle"
	dim d as double
	
	dim s as string
	dim fs as string * 15 'Terrible type btw
	dim z as zstring * 15 'Not terrible type
	dim zp as zstring ptr
	dim w as wstring * 15 'Also not terrible
	dim wp as wstring ptr
	
	union NamedUnion
		dim i as integer<32>
		dim f as single
	end union
	
	dim u as NamedUnion

	dim FBArray(4) as byte
	
	dim PtrArray as MiniUDT ptr
	dim ArrayCount as integer
	
	dim SomePointer as MiniUDt ptr
	
end type

CREATE_SERIALIZER(SimpleUDT, _
	MEMBER_SIMPLE(bool), _
	MEMBER_SIMPLE(i8), _
	MEMBER_SIMPLE(u8), _
	MEMBER_SIMPLE(i16), _
	MEMBER_SIMPLE(u16), _
	MEMBER_SIMPLE(i32), _
	MEMBER_SIMPLE(u32), _
	MEMBER_SIMPLE(l), _
	MEMBER_SIMPLE(ul), _
	MEMBER_SIMPLE(i64), _
	MEMBER_SIMPLE(u64), _
	MEMBER_SIMPLE(li), _
	MEMBER_SIMPLE(uli), _
	MEMBER_SIMPLE(f), _
	MEMBER_SIMPLE(d), _
	MEMBER_SIMPLE(s), _
	MEMBER_SIMPLE(fs), _ 'NOTE: this member will print a warning as fixed length strings are not handled well
	MEMBER_SIMPLE(z), _
	MEMBER_SIMPLE(zp), _
	MEMBER_SIMPLE(w), _
	MEMBER_SIMPLE(wp), _
	MEMBER_NAMED_UNION(u), _
	MEMBER_STATIC_FB_ARRAY(FBarray), _
	MEMBER_DYNAMIC_ARRAY(PtrArray, ArrayCount), _
	MEMBER_SIMPLE(ArrayCount), _
	MEMBER_POINTER(SomePointer))
	
dim mini1 as MiniUDT
dim simple1 as SimpleUDT

'Variable setup

mini1.s = "Hello from nested UDT"

simple1.bool = false
simple1.i8 = -8
simple1.u8 = 255
simple1.i16 = -16
simple1.u16 = 65444
simple1.i32 = -32
simple1.u32 = &hfffffffe
simple1.l = -1234
simple1.ul = 1234
simple1.i64 = -64
simple1.u64 = &hfffffffffffffffe
simple1.li = -5678
simple1.uli = 5678
simple1.f = 8.57f
simple1.d = 3.141592653589793d
simple1.s = "I am of the string class, like a violin"
simple1.fs = "A nice cutoff string"
simple1.z = "A nice cutoff string"
simple1.zp = cast(zstring ptr, @"Zstring master-class")
simple1.w = "I'm sure I could figure something out here"
simple1.wp = @wstr("But, alas, I am too dumb")
simple1.u.f = 9.999999f

for i as integer = 0 to ubound(simple1.FBArray)
	simple1.FBArray(i) = i
next

simple1.ArrayCount = 5
simple1.PtrArray = new MiniUDT[simple1.ArrayCount]

for i as integer = 0 to simple1.ArrayCount - 1
	simple1.PtrArray[i].s = "Nested UDT string " & i
next

simple1.SomePointer = new MiniUDT
simple1.SomePointer->s = "My very own nest egg"

'The real testing
scope
	dim stream as MemoryStreamType
	'dim stream as FileStreamType
	'stream.OpenFile("testSerializer.bin", "w+")
	
	print ""
	print "---Serializing"
	FBSerializer.SerializeToBinary(simple1, stream)
	
	'Variables to deserialize into
	dim simpleBin as SimpleUDT
	dim simpleJSON as SimpleUDT
	
	print ""
	print "---Deserializing"
	stream.Seek(stream._SEEK_START)
	FBSerializer.DeserializeFromBinary(simpleBin, stream)
	print ""
	print "---Serializing to JSON"
	dim as string jsonStr = FBSerializer.SerializeToJSON(simpleBin)
	print jsonStr
	
	print ""
	print "---Validating JSON"
	'Binding json to a temp stream
	dim tmpStream as MemoryStreamType = MemoryStreamType(StrPtr(jsonStr), len(jsonStr))
	dim errorStr as string = FBSerializer.ValidateJSON(simpleJSON, tmpStream)
	if len(errorStr) > 0 then
		print "Validation failed with error:"
		print errorStr
	else
		print "Validation succeeded"
	end if
	
	print ""
	print "---Deserializing JSON"
	tmpStream.Seek(tmpStream._SEEK_START)
	errorStr = FBSerializer.DeserializeFromJSON(simpleJSON, tmpStream)
	if len(errorStr) > 0 then
		print "Deserializing failed with error:"
		print errorStr
	else
		print "Deserializing succeeded (pretty print):"
		print FBSerializer.JSONPrettyPrint(FBSerializer.SerializeToJSON(simpleJSON))
	end if
	
	if simpleBin.PtrArray then
		delete [] simpleBin.PtrArray
	end if
	if simpleBin.SomePointer then
		delete(simpleBin.SomePointer)
	end if
	
	if simpleJSON.PtrArray then
		delete [] simpleJSOn.PtrArray
	end if
	if simpleJSON.SomePointer then
		delete(simpleJSOn.SomePointer)
	end if
	
	'stream.CloseFile()
	
end scope

delete [] simple1.PtrArray
delete(simple1.SomePointer)
'/
#endif
