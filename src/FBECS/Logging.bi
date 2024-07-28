#ifndef Logging_bi
#define Logging_bi

#include once "file.bi"

namespace FBECS

#ifndef dprint
#define dprint(msg) open err for output as #1 : print  #1,msg : close #1 :
#endif

'Set the default to warn if not already set
#ifndef ECS_LOG_LEVEL
#define ECS_LOG_LEVEL 2
#endif

'White
#define ECS_LOG_STAT_COLOR (7)
'Yellow
#define ECS_LOG_WARN_COLOR (14)
'Red
#define ECS_LOG_ERROR_COLOR (4)
'Brown
#define ECS_LOG_TRACE_COLOR (6)

#define ECS_LOG_NAME "ECS_log.txt"
#define ECS_MAX_LOG_SIZE 1024 * 1024 * 250

declare function OpenLog(byref FileHandle as integer<32>) as integer

#macro _Log(_TEXT)
    
#ifdef ECS_LOG_TO_FILE
scope
	dim fileHandle as integer<32>
	dim errorVal as integer
	dim fileLength as integer<64>
	
	static FirstOpenedFlag as ubyte = 1
	
	'Keep the log size to a max
	fileLength = FileLen(ECS_LOG_NAME)
	
	if fileLength < ECS_MAX_LOG_SIZE then
	
		fileHandle = FreeFile()

		errorVal = FBECS.OpenLog(fileHandle)
	
		if errorVal > 0 then
			dprint("ECS Logging Error: Failed to open file:"; ECS_LOG_NAME)
		else
			print #fileHandle, _TEXT
		end if

		Close(fileHandle)
	
	end if
	
end scope
#endif
    :dprint(_TEXT):
#endmacro

'All of these macros are sort of relying on dead
'code elimination by the compiler

#macro LogError(_TEXT)
if ECS_LOG_LEVEL then
	scope
		dim saveColor as uinteger<32> = Color()
		Color(ECS_LOG_ERROR_COLOR)
		_Log(__FUNCTION__;!": ERROR: \t";_TEXT)
		Color(LoWord(saveColor))
		sleep
	end scope
end if
#endmacro

#macro LogStat(_TEXT)
if ECS_LOG_LEVEL >= 1 then
	scope
		dim saveColor as uinteger<32> = Color()
		Color(ECS_LOG_STAT_COLOR)
		_Log(!"LOG: \t";_TEXT)
		Color(LoWord(saveColor))
	end scope
end if
#endmacro

#macro LogWarn(_TEXT)
if ECS_LOG_LEVEL >= 2 then
	scope
		dim saveColor as uinteger<32> = Color()
		Color(ECS_LOG_WARN_COLOR)
		_Log(__FUNCTION__;!": WARNING: \t";_TEXT)
		Color(LoWord(saveColor))
	end scope
end if
#endmacro

#macro LogTrace(_TEXT)
if ECS_LOG_LEVEL >= 3 then
	scope
		dim saveColor as uinteger<32> = Color()
		Color(ECS_LOG_TRACE_COLOR)
		_Log(!"TRACE: ";_TEXT)
		Color(LoWord(saveColor))
	end scope
end if
#endmacro

end namespace

#endif
