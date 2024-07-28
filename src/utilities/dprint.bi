#ifndef dprint_bi
#define dprint_bi

#ifndef DEBUG_MODE
#define DEBUG_MODE 1
#endif

'Use to ensure always printing to the console, regardless of whether we're using Screen or not
#ifndef dprint
#define dprint(msg) if DEBUG_MODE = 1 then open err for output as #1 : print  #1,msg : close #1 : endif:
#endif

#endif
