#ifndef Stream_bi
#define Stream_bi

#include once "crt/stdio.bi"

'A very simple interface for streams to work with
type StreamInterface extends Object
	
	enum SeekEnum
		'Stupid stdio claiming SEEK_END and SEEK_CUR...
		_SEEK_START = 0
		_SEEK_END = 1
		_SEEK_CUR = 2
	end enum
	
	'Writes from the data source to the stream
	'Returns number of bytes written
	declare abstract function Write( _
		dataSrc as any ptr, _
		size as integer) as integer
	
	'Reads from the stream into the data source
	'Returns number of bytes read
	declare abstract function Read( _
		dataDst as any ptr, _
		size as integer) as integer
	
	'Moves the stream cursor given a SeekEnum option and an offset.
	'Returns 0 on success, non 0 on error
	declare abstract function Seek( _
		seekOption as SeekEnum, _
		offset as integer = 0) as integer
	
	'Returns the stream head index on success, -1 on failure
	declare abstract function Tell() as integer
	
	'Returns some error code
	declare abstract function GetError() as integer
	
	declare virtual destructor()
		
end type

type MemoryStreamType extends StreamInterface

	enum ErrorCodeEnum
		END_OF_READ = 1 SHL 0
		END_OF_WRITE = 1 SHL 1
		NULL_MEMORY = 1 SHL 2
		ILLEGAL_SEEK = 1 SHL 3
	end enum

    type AllocatorType

        'A block allocator type thing
		
		'Size of a block as a power of 2 (10 = 1024 bytes)
		'Configure this to your liking
        const as uinteger<32> BlockSizePow = 10
		const as uinteger<32> BlockSizeMask = (1 SHL BlockSizePow) - 1

        dim as ubyte ptr ptr Chunks
        dim as integer Size 'Size of Chunks array
        dim as integer Count 'Count of in-use bytes

		declare const property BlockSize() as uinteger<32>
		
        'Used to allocate new space
		'Returns the index to the start of the allocated space
        declare function Reserve(inCount as integer) as integer
		
		declare operator [] (index as integer) byref as ubyte

    end type

	private:
	'Determines if this stream uses the internal allocator
	'or a user passed in byte array
	dim as ubyte Owner
	
	public:
	
	type BoundMemoryType
		'I don't wanna just call this "Data" as it'll be confusing
		dim as ubyte ptr UserData
		'Length of bound memory in bytes
		dim as integer Length
	end type

	union
		dim as AllocatorType Data
		dim as BoundMemoryType BoundMemory
	end union
	
	dim as integer StreamHead
	dim as integer StreamTail
	
	dim as ErrorCodeEnum ErrorCode
	
	'Constructs an allocator based memory stream
	declare constructor()
	'Constructs a user bound memory stream
	'inMemory is the pointer to the data
	'inLength is the size of the array in bytes
	declare constructor( _
		inMemory as any ptr, _
		inLength as integer)
	
    declare destructor()
	
	declare sub SetErrorCode(code as ErrorCodeEnum)
	declare sub ClearErrorCode(code as ErrorCodeEnum)
	
	'[Internal] Returns the number of bytes remaining in a chunk from "start"
	declare function GetRemainingBytesFrom(start as integer) as integer
	
	'Returns the total number of bytes in the stream
	declare function GetLength() as integer
	
	'Returns the current error code state
	declare function GetError() as integer	
	
	'Returns the number of remaining bytes in the stream
	declare function GetRemainingBytes() as integer
	
	'Writes to the user bound memory
	declare function WriteBoundMemory( _
		dataSrc as any ptr, _
		size as integer) as integer
	
	'Writes to the chunk allocator
	declare function WriteChunks( _
		dataSrc as any ptr, _
		size as integer) as integer
	
	declare function Write( _
		dataSrc as any ptr, _
		size as integer) as integer
	
	'Reads from the user bound memory
	declare function ReadBoundMemory( _
		dataDst as any ptr, _
		size as integer) as integer
	
	'Reads from the chunk allocator
	declare function ReadChunks( _
		dataDst as any ptr, _
		size as integer) as integer
		
	declare function Read( _
		dataDst as any ptr, _
		size as integer) as integer
	
	'Returns 0 on success,
	'1 on invalid offset (negative value on _SEEK_START, positive value on SEEK_END)
	'2 on offset that exceeds the stream bounds (negative read/write head, or exceeds tail)
	declare function Seek( _
		seekOption as SeekEnum, _
		offset as integer = 0) as integer
	
	'Returns the current stream head
	declare function Tell() as integer
	
end type

type FileStreamType extends StreamInterface

	dim as FILE ptr FileHandle
	dim as ubyte Owner
	
	declare constructor()
    declare destructor()
	
	'Opens a file for <mode> for streaming.
	'The stream owns the file and cleans it up.
	'Returns 0 if open succeeded, non 0 if error
	declare function OpenFile( _
		fileName as string, _
		mode as string) as integer
	
	'Binds to a file already opened.  The stream
	'does not own the file and will not clean it up.
	'Returns 0 if success, non-0 if error
	declare function BindFile( _
		inFileHandle as const FILE ptr) as integer
	
	'Unbinds a previously bound file
	'Returns 0 if the file was unbound
	'Returns non-0 if the file is owned or nothing is bound
	declare function UnbindFile() as integer
	
	'Closes the current file, if opened and owned
	'Returns 0 if the file was closed.
	'Returns non-0 if error.
	'Error could be that the file wasn't owned, 
	'no file was opened, or if fclose reported an error.
	declare function CloseFile() as integer
	
	'Writes to the file, returns number of bytes written
	declare function Write( _
		dataSrc as any ptr, _
		size as integer) as integer
	
	'Reads from the file, returns number of bytes read
	declare function Read( _
		dataDst as any ptr, _
		size as integer) as integer
	
	declare function Seek( _
		seekOption as SeekEnum, _
		offset as integer = 0) as integer
	
	declare function Tell() as integer
	
	'Returns the error from file IO (does not return other errors)
	declare function GetError() as integer
	
end type

#endif
