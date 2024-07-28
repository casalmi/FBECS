#ifndef ECSEvents_bi
#define ECSEvents_bi

#include once "../utilities/DynamicArray.bi"
#include once "Entity.bi"
#include once "System.bi"

namespace FBECS

type EventIDType as uinteger<64>

#define FBECS_EVENT_CALLBACK_SIGNATURE _ \
        byref inECS as FBECS.__ECSInstanceType, _ \
        byref inEvents as DynamicArrayType, _ \
        deltaTime as double

type ECSEventQueueType
	
	'A minimum number of events to pre-size the array to
	'to prevent excess reallocations
	const MINIMUM_EVENT_COUNT as uinteger<32> = 8
	
	'Human readable name
	dim as string Name 
	
	'Array holding the events
	dim as DynamicArrayType Events = DynamicArrayType(0)
	
	'Array holding deferred events
	dim as DynamicArrayType DeferredEvents = DynamicArrayType(0)
	
	'Event ID that indexes into the system's array
	dim as EventIDType ID
	
	'Indicates if the event is a 0 size event
	'Only one of such event can be queued at any time
	dim as ubyte OneOffFlag
	
	'Indicates whether or not this queue is being used
	'by an event callback system
	dim as ubyte Locked
	
	'Destructor hook
    dim Dtor as sub(as any ptr)
	
	declare constructor( _
		inName as string, _
		inEventSize as uinteger<32>, _
        inDtor as sub(as any ptr) = 0)
	
	declare destructor()
	
	'Reserve enough space in the queue to fit at least inEventCount more events
	declare sub PreAllocate( _
		inEventCount as uinteger)
	
	declare sub MoveEvent( _
		inDst as any ptr, _
		inSrc as any ptr)
	
	'Add an event to the queue
	declare sub PushEvent( _
		inEvent as any ptr)
	
	'Add an event to the queue
	declare sub PushDeferredEvent( _
		inEvent as any ptr)
	
	'Merge deferred events into the queue
	declare sub MergeDeferredEvents()
	
	'Delete all non-deferred events
	declare sub Empty()
	
	declare operator Let ( _
        byref rightSide as ECSEventQueueType)
	
end type

end namespace

#endif
