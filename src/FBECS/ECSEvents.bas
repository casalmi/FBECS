#ifndef ECSEvents_bas
#define ECSEvents_bas

#include once "FBECS.bi"

namespace FBECS

constructor ECSEventQueueType( _
		inName as string, _
		inEventSize as uinteger<32>, _
        inDtor as sub(as any ptr) = 0)
	
	this.Name = inName
	this.Events.Destructor()
	this.Events.Constructor(inEventSize, MINIMUM_EVENT_COUNT)
	this.DeferredEvents.Destructor()
	this.DeferredEvents.Constructor(inEventSize, MINIMUM_EVENT_COUNT)

	this.Dtor = inDtor

	this.OneOffFlag = iif(inEventSize = 0, 1, 0)
	this.Locked = 0
	
end constructor

destructor ECSEventQueueType()

	if this.Dtor then
		for i as integer = 0 to this.Events.Count - 1
			'We don't know the type so we have to do it this way
			this.Dtor(@this.Events[i])
		next
		for i as integer = 0 to this.DeferredEvents.Count - 1
			this.Dtor(@this.DeferredEvents[i])
		next
	end if

end destructor

sub ECSEventQueueType.PreAllocate( _
		inEventCount as uinteger)

	if this.OneOffFlag then
		LogError("Reserving is not supported for 0 size events")
	end if

	this.Events.PreAllocate(inEventCount)

end sub

sub ECSEventQueueType.MoveEvent( _
		inDst as any ptr, _
		inSrc as any ptr)
	
	'Move the memory from inSrc to inDst and clear inSrc
	'The Events list holds the correct element size
	memmove(inDst, inSrc, this.Events.ElementSize)
	memset(inSrc, 0, this.Events.ElementSize)
	
end sub

sub ECSEventQueueType.PushEvent( _
		inEvent as any ptr)
	
	if this.OneOffFlag then
		'Handle the case where the event is 0 size
		if this.Events.Count >= 1 then
			'There can only be one of such event at any given time
			return
		end if
		
		this.Events.Reserve()
		return
		
	end if
	
	dim index as uinteger
	index = this.Events.Reserve()

	this.MoveEvent(@this.Events[index], inEvent)

end sub

sub ECSEventQueueType.PushDeferredEvent( _
		inEvent as any ptr)
	
	if this.OneOffFlag then
		'Handle the case where the event is 0 size
		if this.DeferredEvents.Count >= 1 then
			'There can only be one of such event at any given time
			return
		end if
		
		this.DeferredEvents.Reserve()
		return
		
	end if
	
	dim index as uinteger
	index = this.DeferredEvents.Reserve()

	this.MoveEvent(@this.DeferredEvents[index], inEvent)
	
end sub

sub ECSEventQueueType.MergeDeferredEvents()

	if this.DeferredEvents.Count = 0 then
		return
	end if
	
	for i as integer = 0 to this.DeferredEvents.Count - 1
		
		if this.OneOffFlag ANDALSO this.Events.Count > 0 then
			return
		end if

		this.Events.PushUDT(@this.DeferredEvents[i])
	next
	
	'Everything has been transferred so we can safely delete all this
	this.DeferredEvents.ResizeNoSave(MINIMUM_EVENT_COUNT)

end sub

sub ECSEventQueueType.Empty()

	if this.Dtor then
		for i as integer = 0 to this.Events.Count - 1
			'We don't know the type so we have to do it this way
			this.Dtor(@this.Events[i])
		next
	end if
	
	this.Events.ResizeNoSave(MINIMUM_EVENT_COUNT)
	
end sub

operator ECSEventQueueType.Let ( _
        byref rightSide as ECSEventQueueType)

	this.Name = rightSide.Name
	this.Events = rightSide.Events
	this.DeferredEvents = rightSide.DeferredEvents
	this.Dtor = rightSide.Dtor
	this.OneOffFlag = rightSide.OneOffFlag

end operator

end namespace

#endif
