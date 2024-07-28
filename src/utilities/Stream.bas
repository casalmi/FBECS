#ifndef Stream_bas
#define Stream_bas

#include "crt/mem.bi"

#include once "Stream.bi"

'--------------------------STREAM INTERFACE--------------------------
destructor StreamInterface()
end destructor

'--------------------------MEMORY STREAM--------------------------

const property MemoryStreamType.AllocatorType.BlockSize() as uinteger<32>
	return 1 SHL this.BlockSizePow
end property

function MemoryStreamType.AllocatorType.Reserve(inCount as integer) as integer
	
	dim retVal as integer = this.Count
	dim newCount as integer = this.Count + inCount
	dim neededChunks as integer = (newCount SHR this.BlockSizePow) + 1
	
	if neededChunks > this.Size then
		
		'Need to resize the chunk array
		dim temp as ubyte ptr ptr
		
		temp = new ubyte ptr[neededChunks]
		for i as integer = 0 to this.Size - 1
			temp[i] = this.Chunks[i]
		next
		
		for i as integer = this.Size to neededChunks - 1
			temp[i] = new ubyte[this.BlockSize]
		next
		
		if this.Chunks then
			delete [] this.Chunks
		end if
		
		this.Chunks = temp
	
	end if
	
	this.Count = newCount
	this.Size = neededChunks
	
	return retVal

end function

operator MemoryStreamType.AllocatorType.[] (index as integer) byref as ubyte
	return this.Chunks[(index SHR this.BlockSizePow)][(index AND this.BlockSizeMask)]
end operator

constructor MemoryStreamType()
	this.Owner = 1
end constructor

constructor MemoryStreamType( _
		inMemory as any ptr, _
		inLength as integer)

	this.Owner = 0
	
	if inLength < 0 then
		return
	end if
	
	if inMemory = 0 then
		this.SetErrorCode(this.NULL_MEMORY)
	end if
	
	this.BoundMemory.UserData = cast(ubyte ptr, inMemory)
	this.BoundMemory.Length = inLength
	
	this.StreamHead = 0
	this.StreamTail = inLength
	
end constructor

destructor MemoryStreamType()
	
	if this.Owner = 0 then
	
		this.BoundMemory.UserData = 0
		this.BoundMemory.Length = 0
		
	else
	
		if this.Data.Chunks then
		
			for i as integer = 0 to this.Data.Size - 1
				delete [] this.Data.Chunks[i]
			next
			
			delete [] this.Data.Chunks
			
		end if
		
		this.Data.Size = 0
		this.Data.Count = 0
		
	end if

end destructor

sub MemoryStreamType.SetErrorCode(code as ErrorCodeEnum)
	this.ErrorCode OR= code
end sub

sub MemoryStreamType.ClearErrorCode(code as ErrorCodeEnum)
	this.ErrorCode = this.ErrorCode AND (NOT code)
end sub

function MemoryStreamType.GetError() as integer
	return cast(integer, this.ErrorCode)
end function

function MemoryStreamType.GetRemainingBytesFrom(start as integer) as integer
	if this.Owner = 0 then
		return this.BoundMemory.Length - start
	else
		return this.Data.BlockSize - (start AND this.Data.BlockSizeMask)
	end if
end function

function MemoryStreamType.GetLength() as integer
	return this.StreamTail
end function

function MemoryStreamType.GetRemainingBytes() as integer
	return this.StreamTail - this.StreamHead
end function

function MemoryStreamType.WriteBoundMemory( _
		dataSrc as any ptr, _
		size as integer) as integer
	
	if this.BoundMemory.UserData = 0 then
		this.SetErrorCode(this.NULL_MEMORY)
		return 0
	end if
	
	dim toWrite as integer
	dim remaining as integer = this.GetRemainingBytes()

	'Bind write size to max of remaining bytes in bound array
	toWrite = iif(remaining < size, remaining, size)
	
	memcpy(@this.BoundMemory.UserData[this.StreamHead], dataSrc, toWrite)
	
	this.StreamHead += toWrite
	
	if this.StreamHead = this.StreamTail then
		this.SetErrorCode(this.END_OF_WRITE)
	end if
	
	return toWrite

end function

function MemoryStreamType.WriteChunks( _
		dataSrc as any ptr, _
		size as integer) as integer

	dim bytesRemaining as integer = size
	dim bytesWritten as integer = 0
	dim start as integer
	dim toWrite as integer
	dim src as any ptr = dataSrc
	dim available as integer = this.GetRemainingBytes()
	
	assert(available >= 0)
	
	if available > 0 then
		'We have available space to write over
		start = this.StreamHead
		if available < size then
			'Allocate any remainder not available
			this.Data.Reserve(size - available)
		end if
	else
		start = this.Data.Reserve(size)
	end if

	while bytesWritten < size
		
		dim remainder as integer = this.GetRemainingBytesFrom(start)
		
		'Only write up to the remaining number of bytes left in this block
		toWrite = iif(bytesRemaining > remainder, remainder, bytesRemaining)
		
		memcpy(@this.Data[start], src, toWrite)
		
		bytesWritten += toWrite
		bytesRemaining -= toWrite
		src += toWrite
		start += toWrite
		
	wend
	
	'Increment the head
	this.StreamHead += bytesWritten
	
	'Increment the tail if the head surpassed it
	if this.StreamHead > this.StreamTail then
		this.StreamTail = this.StreamHead
		this.ClearErrorCode(this.END_OF_READ)
	end if

	return bytesWritten
	
end function

function MemoryStreamType.Write( _
		dataSrc as any ptr, _
		size as integer) as integer
	
	if this.Owner = 0 then
		return this.WriteBoundMemory(dataSrc, size)
	else
		return this.WriteChunks(dataSrc, size)
	end if

end function

function MemoryStreamType.ReadBoundMemory( _
		dataDst as any ptr, _
		size as integer) as integer
	
	if this.BoundMemory.UserData = 0 then
		this.SetErrorCode(this.NULL_MEMORY)
		return 0
	end if
	
	dim toRead as integer
	dim available as integer = this.GetRemainingBytes()

	'Bind read size to max of remaining bytes in bound array
	toRead = iif(available < size, available, size)
	
	memcpy(dataDst, @this.BoundMemory.UserData[this.StreamHead], toRead)
	
	this.StreamHead += toRead
	
	if this.StreamHead >= this.StreamTail then
		this.SetErrorCode(this.END_OF_READ)
	end if
	
	return toRead
	
end function

function MemoryStreamType.ReadChunks( _
		dataDst as any ptr, _
		size as integer) as integer

	dim bytesRemaining as integer = size
	dim bytesRead as integer = 0
	dim start as integer = this.StreamHead
	dim toRead as integer
	dim dst as any ptr = dataDst
	
	while bytesRead < size ANDALSO start < this.StreamTail
		
		dim remainder as integer = this.GetRemainingBytesFrom(start)
		
		'Only read up to the remaining number of bytes left in this block
		toRead = iif(bytesRemaining > remainder, remainder, bytesRemaining)
		
		'Only read up to the number of bytes left in the stream
		if start + toRead >= this.StreamTail then
			toRead = this.StreamTail - start
			this.SetErrorCode(this.END_OF_READ)
		end if
		
		memcpy(dst, @this.Data[start], toRead)
		
		bytesRead += toRead
		bytesRemaining -= toRead
		dst += toRead
		start += toRead
		
		if this.ErrorCode ANDALSO this.END_OF_READ then
			exit while
		end if
		
	wend
	
	this.StreamHead += bytesRead
	
	return bytesRead
	
end function

function MemoryStreamType.Read( _
		dataDst as any ptr, _
		size as integer) as integer
	
	if this.Owner = 0 then
		return this.ReadBoundMemory(dataDst, size)
	else
		return this.ReadChunks(dataDst, size)
	end if
	
end function

function MemoryStreamType.Seek( _
		seekOption as SeekEnum, _
		offset as integer = 0) as integer

	select case as const seekOption
		case this._SEEK_START
			
			if offset < 0 then
				this.SetErrorCode(this.ILLEGAL_SEEK)
				return 1
			end if
			
			if offset > this.StreamTail then
				
				this.SetErrorCode(this.ILLEGAL_SEEK)
				return 2
				
			end if
			
			this.StreamHead = offset
			
		case this._SEEK_END
			
			if offset > 0 then
				this.SetErrorCode(this.ILLEGAL_SEEK)
				return 1
			end if
			
			if this.StreamTail + offset < 0 then
				
				this.SetErrorCode(this.ILLEGAL_SEEK)
				return 2
				
			end if
			
			this.StreamHead = this.StreamTail + offset

		case this._SEEK_CUR
			
			dim newHead as integer = this.StreamHead + offset
			
			if newHead < 0 ORELSE newHead > this.StreamTail then
				this.SetErrorCode(this.ILLEGAL_SEEK)
				return 2
			end if
			
			this.StreamHead = newHead
		
		case else
			
			this.SetErrorCode(this.ILLEGAL_SEEK)
			return 1
			
	end select
	
	'Clear end-of errors
	if this.StreamHead < this.StreamTail then
		this.ClearErrorCode(this.END_OF_READ)
		this.ClearErrorCode(this.END_OF_WRITE)
	end if
	
	this.ClearErrorCode(this.ILLEGAL_SEEK)

	return 0
	
end function

function MemoryStreamType.Tell() as integer
	return this.StreamHead
end function

'--------------------------FILE STREAM--------------------------

constructor FileStreamType()
end constructor

destructor FileStreamType()
	
	if this.FileHandle ANDALSO this.Owner then
		fclose(this.FileHandle)
	end if
	
end destructor

function FileStreamType.OpenFile(_
		fileName as string, _
		mode as string) as integer

	this.FileHandle = fopen(StrPtr(fileName), StrPtr(mode))
		
	if this.FileHandle = 0 then
		return 1
	end if
	
	this.Owner = 1
	
	return 0

end function

function FileStreamType.BindFile( _
		inFileHandle as const FILE ptr) as integer
	
	if this.FileHandle ANDALSO this.Owner then
		return 1
	end if
	
	this.FileHandle = cast(FILE ptr, inFileHandle)
	this.Owner = 0
	
	return 0
	
end function

function FileStreamType.UnbindFile() as integer
	
	if this.FileHandle = 0 ORELSE this.Owner <> 0 then
		return 1
	end if
	
	this.FileHandle = 0
	return 0
	
end function

function FileStreamType.CloseFile() as integer
	
	if this.FileHandle ANDALSO this.Owner then
		var retVal = fclose(this.FileHandle)
		if retVal then
			'fclose failed, use GetError()
			'Don't clear the file handle as we need to close it properly
			return retVal
		end if
		this.FileHandle = 0
		
		return 0
	end if
	
	'No file opened or not owner, use brain
	return 1
	
end function

function FileStreamType.Write( _
		dataSrc as any ptr, _
		size as integer) as integer
	
	'Tell fwrite you're writing one big chunk of data.
	return fwrite(dataSrc, size, 1, this.FileHandle) * size
	
end function

function FileStreamType.Read( _
		dataDst as any ptr, _
		size as integer) as integer

	return fread(dataDst, size, 1, this.FileHandle) * size

end function

function FileStreamType.Seek( _
		seekOption as SeekEnum, _
		offset as integer = 0) as integer

	dim retVal as integer

	select case as const seekOption
	
		case this._SEEK_START
			retVal = fseek(this.FileHandle, offset, SEEK_SET)
		case this._SEEK_END
			retVal = fseek(this.FileHandle, offset, SEEK_END)
		case this._SEEK_CUR
			retVal = fseek(this.FileHandle, offset, SEEK_CUR)
		case else
			'Delibrately cause an error
			retVal = fseek(this.FileHandle, 0, -1)
			
	end select

	return retVal

end function

function FileStreamType.GetError() as integer
	return cast(integer, ferror(this.FileHandle))
end function

function FileStreamType.Tell() as integer
	return ftell(this.FileHandle)
end function

#endif
