#ifndef Logging_bas
#define Logging_bas

#include once "Logging.bi"

namespace FBECS

function OpenLog(byref FileHandle as integer<32>) as integer
    
    'This function does nothing other than delete the log on a fresh run
    'and then append afterward
    
    static FirstOpenedFlag as ubyte = 1
    dim retError as integer
    
    if FirstOpenedFlag then
        retError = Open(ECS_LOG_NAME for output as fileHandle)
        FirstOpenedFlag = 0
    else
        retError = Open(ECS_LOG_NAME for append as fileHandle)
    end if
    
    return retError
    
end function

end namespace

#endif
