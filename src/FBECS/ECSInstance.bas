#ifndef ECSInstance_bas
#define ECSInstance_bas

#include once "crt/stdlib.bi"

#include once "FBECS.bi"

namespace FBECS

GENERATE_DICTIONARY_TYPE(EntityIDType, FBECS.EntityLocationSpecifierType, DictionaryType_EntIDEntSpecifier)
GENERATE_DICTIONARY_TYPE(ComponentIDType, ComponentDescriptorType, DictionaryType_CompIDCompDesc)
GENERATE_DICTIONARY_TYPE(ComponentIDType, DynamicArrayType ptr, DictionaryType_CompIDDynamicArray)
GENERATE_DICTIONARY_TYPE(ComponentIDListType, ArchetypeIDType, DictionaryType_CompIDListArchID)

/''''''''''''''''''''''''''''''''''''''''''Internal use macros''''''''''''''''''''''''''''''''''''''''''/

'Undefined at the end of the file
'This allows for a distinction between uninitialized archetypes vs deleted ones
#define ARCHETYPE_TOMBSTONE (cast(ArchetypeType ptr, (NOT 0)))

/''''''''''''''''''''''''''''''''''''''''''End of internal use macros''''''''''''''''''''''''''''''''''''''''''/

destructor ECSInstanceType.ModuleInfoType()

	FOR_IN(n, string, this.SystemsList)
		n = ""
	FOR_IN_NEXT
	
	FOR_IN(n, string, this.ComponentsList)
		n = ""
	FOR_IN_NEXT
	
	FOR_IN(n, string, this.EventsList)
		n = ""
	FOR_IN_NEXT
	
end destructor

/''''''''''''''''''''''''''''''''''''''''''ECS API implementation''''''''''''''''''''''''''''''''''''''''''/

constructor ECSInstanceType()

    'Reserve index ID 0 archetype for the null archetype
    'This archetype has no components
    dim tempArchetype as ArchetypeType ptr
    dim tempComponentIDList as ComponentIDListType
    dim tempArray(any) as uinteger<32>
    tempArchetype = _
        new ArchetypeType( _
            cast(ArchetypeIDType, -1), _
            tempComponentIDList, _
            tempArray())
   
    this.HighestEntityID = 0
    
    this.ArchetypeList.Push(tempArchetype)
	
	this.EventQueueList.Reserve()
	this.EventCallbackList.Reserve()
	
	'Set up default phases
	this.PhaseList.Reserve(this.PHASE_END_MARKER)
	FOR_IN(phase, DynamicArrayType ptr, this.PhaseList)
		phase = new DynamicArrayType(sizeof(PipelineMapType))
	FOR_IN_NEXT
	
	'Set up global module namespace
	this.Modules.Reserve(1)
	dim module as ECSInstanceType.ModuleInfoType ptr = _
		cast(ECSInstanceType.ModuleInfoType ptr, @this.Modules[0])
	'Default construct + swap technique for construction
	dim tmp as ECSInstanceType.ModuleInfoType
	swap tmp, *module
	module->Name = ""
	
    this.SetSystemRefreshRate(60)
    
    this.ChildOfTag = this.RegisterComponent(0, "ChildOf")

end constructor

destructor ECSInstanceType()
    
    this.DeferMode = 0
    
    this.FlushCommandBuffer()
    
	FOR_IN(archetype, ArchetypeType ptr, this.ArchetypeList)
        
        if archetype = ARCHETYPE_TOMBSTONE then
            'This is our tombstone value.  Maybe make this a define or something
            LogTrace("Archetype already deleted.  Index was: ";FOR_IN_ITER)
            FOR_IN_CONTINUE
        end if
		
        LogTrace( _
            "Deleting archetype: ";archetype->ID;", "; _
            this.ComponentListHumanReadable(archetype->ComponentIDList))
		
		this.DestructArchetypeComponents(archetype)
		
        delete(archetype)
		
	FOR_IN_NEXT
	
	LogTrace("Deleting event data")
	FOR_IN(eventQueue, ECSEventQueueType, this.EventQueueList)
		eventQueue.Destructor()
	FOR_IN_NEXT
    
    DICTIONARY_FOREACH_START(this.ComponentToArchetypeIDListDictionary, key, value)
        if *value then
            LogTrace( _
                !"Deleting archetype ID list for "; _
                "component: ";this.ComponentIDHumanReadable(*key))
            delete(*value)
        end if
    DICTIONARY_FOREACH_NEXT
    
	DICTIONARY_FOREACH_START(this.PairToArchetypeIDListDictionary, key, value)
		if *value then
			delete(*value)
		end if
	DICTIONARY_FOREACH_NEXT
	
	DICTIONARY_FOREACH_START(this.ComponentToCachedQueryListDictionary, key, value)
		if *value then
			delete(*value)
		end if
	DICTIONARY_FOREACH_NEXT
	
	FOR_IN(phase, DynamicArrayType ptr, this.PhaseList)
		'Because the phase callback has a string, we need
		'to destruct this manually.
		FOR_IN(entry, PipelineMapType, *phase)
			entry.Name = ""
		FOR_IN_NEXT
		
		delete(phase)
		
	FOR_IN_NEXT
	
	'Event queues have a non-simple destructor
	FOR_IN(eventQueue, ECSEventQueueType, this.EventQueueList)
		eventQueue.Destructor()
	FOR_IN_NEXT
	
	'Module info has a non-simple destructor
	FOR_IN(module, ECSInstanceType.ModuleInfoType, this.Modules)
		module.Destructor()
	FOR_IN_NEXT
	
	'NOTE: Unlike event queues, the SystemList only holds references
	'to externally created systems.  Cleaning those up is not the 
	'responsibility of the ECSInstance.
	
    LogTrace("Instance deleted")
    
end destructor

function ECSInstanceType.CreateNewEntity overload () as EntityIDType

    dim tempComponentIDList as ComponentIDListType
    
    return this.CreateNewEntity(tempComponentIDList)

end function

function ECSInstanceType.CreateNewEntity( _
        byref inComponentList as ComponentIDListType) as EntityIDType
    
    'Generate a new entity and return its ID
    dim retVal as EntityIDType
    dim archetypeID as ArchetypeIDType
	
    retVal = this.GetNextEntityID()
    
	archetypeID = this.GetOrCreateArchetypeIDFromComponentList(inComponentList)
	
    this.CreateEntityFromID(retVal, archetypeID)
    
    return retVal
    
end function

function ECSInstanceType.CreateNewComponent() as EntityIDType

    dim retVal as EntityIDType
	dim archetypeID as ArchetypeIDType
	
    dim componentList as ComponentIDListType

    retVal = this.GetNextUnusedEntityID()
	
	archetypeID = this.GetOrCreateArchetypeIDFromComponentList(componentList)
	
    this.CreateEntityFromID(retVal, archetypeID)

    return retVal

end function

sub ECSInstanceType.CreateEntityFromID( _
        inEntityID as EntityIDType, _
		inArchetypeID as ArchetypeIDType)

    'Create an entity from a given ID and component list
    'dim archetypeID as ArchetypeIDType
    
    dim archetypeRef as ArchetypeType ptr
    
    dim location as EntityLocationSpecifierType
	
	if this.DeferMode then
	
		LogTrace( _
			"Deferring create entity: ";inEntityID.ToString(); _
			" with archetype ID: ";inArchetypeID)
	
		this.CommandBuffer.DeferCreateEntity(inEntityID, inArchetypeID)
		
		'Reserve this entity
		if this.EntityToLocationDictionary.KeyExists(inEntityID) then
			LogError("Expected unused entity, got collision: ";inEntityID.ToString())
		end if
		this.EntityToLocationDictionary[inEntityID]
		
		return
	
	end if

    location = this.AddEntityToArchetype(inEntityID, inArchetypeID)
    
    'Insert the entity id to (archetype, index) tuple into the dictionary
    this.EntityToLocationDictionary[inEntityID] = location

end sub

function ECSInstanceType.GetNextUnusedEntityID() as EntityIDType
    
    this.HighestEntityID += 1
    return cast(uinteger<64>, this.HighestEntityID)

end function

function ECSInstanceType.GetNextEntityID() as EntityIDType
    
	'TODO: this will have to be atomic if multithreading support is added
	
    dim retID as EntityIDType
    
    if this.DeletedEntityIDList.Count > 0 then
        'Grab from the candy bag
        'Return LAST item in the list
        retID = *DYNAMIC_ARRAY_CAST(EntityIDType ptr, this.DeletedEntityIDList, this.DeletedEntityIDList.Count-1)
        this.DeletedEntityIDList.Remove(this.DeletedEntityIDList.Count-1)
		
        return retID
    end if
    
    return this.GetNextUnusedEntityID()
    
end function

function ECSInstanceType.EntityExists( _
        inEntityID as EntityIDType) as integer

    return this.EntityToLocationDictionary.KeyExists(inEntityID)

end function

function ECSInstanceType.GeneratePairComponent( _
        inBaseID as ComponentIDType, _
        inTargetID as ComponentIDType) as ComponentIDType

    dim retID as ComponentIDType
    
    'Combine the IDs: base in the lower 32 bits, target in the upper 32 bits
    retID.EntityID = cast(uinteger<64>, inBaseID)
    retID.TargetID = cast(uinteger<64>, inTargetID)
    
    return retID
    
end function

function ECSInstanceType.RegisterComponent( _
        inComponentTypeSize as uinteger<32>, _
        inComponentName as zstring ptr, _
        inComponentCtor as sub(as any ptr) = 0, _
        inComponentDtor as sub(as any ptr) = 0, _
        inComponentCopy as sub(as any ptr, as any ptr) = 0, _
        inComponentMove as sub(as any ptr, as any ptr) = 0) as ComponentIDType
    
    dim componentID as ComponentIDType
    
    dim componentList as ComponentIDListType
	
	if inComponentName = 0 then
		LogError("Component requires a name")
	else
		'Enforce name uniqueness
		'This will help catch accidental double registers
		'of the same component
		DICTIONARY_FOREACH_START(this.ComponentDescriptorDictionary, key, value)
			if value->Name = *inComponentName then
				LogError( _
					"Component name collision: ";*inComponentName; _
					;" was already registered")
			end if
		DICTIONARY_FOREACH_NEXT
	end if
	
    if (inComponentCopy <> 0) <> (inComponentMove <> 0) then
        'Dtor, copy, and move must show up together
        LogError( _
            !"If Dtor, Copy, or Move is provided, all 3 must be provided\n"; _
            "For component: ";*inComponentName)
        
    end if
    
	if (inComponentCtor ORELSE inComponentDtor ORELSE _
		inComponentCopy ORELSE inComponentMove) ANDALSO inComponentTypeSize = 0 then
		
		LogError( _
			"Cannot have lifetime functions "; _
			"Ctor, Dtor, Copy, or Move on a null size component: ";*inComponentName)
		
	end if
	
    componentID = this.CreateNewComponent()

    dim tempComponent as ComponentDescriptorType = ComponentDescriptorType( _
        componentID, _
        inComponentTypeSize, _
        *inComponentName, _
        inComponentCtor, _
        inComponentDtor, _
        inComponentCopy, _
        inComponentMove)
    
    if this.ComponentDescriptorDictionary.KeyExists(componentID) then
        LogError("Component collision: ";componentID.ToString())
    end if
    
    this.ComponentDescriptorDictionary[componentID] = tempComponent
	
    this.ComponentToArchetypeIDListDictionary[componentID] = _
        new DynamicArrayType(sizeof(ArchetypeIDType))
	
	if this.ComponentToCachedQueryLIstDictionary.KeyExists(componentID) then
		LogError("Component already exists in cached query dictionary: "; _
			this.ComponentIDHumanReadable(componentID))
	end if
	
	this.ComponentToCachedQueryListDictionary[componentID] = _
		new DynamicArrayType(sizeof(QueryType ptr))
	
	'Push this component into our module's namespace
	dim byref module as ECSInstanceType.ModuleInfoType = _
		*cast(ECSInstanceType.ModuleInfoType ptr, @this.Modules[this.ModuleNamespaceIndex])
	dim index as uinteger = module.ComponentsList.Reserve(1)
	
	'Copy the string name in with namespace if needed
	dim byref _name as string = *cast(string ptr, @module.ComponentsList[index])
	_name = *inComponentName
	
    LogStat( _
        "Registered component: ";*inComponentName; _
        ", size: ";inComponentTypeSize; _
        " ID: ";componentID.ToString())
    LogTrace("    ctor=";inComponentCtor;", dtor=";inComponentDtor;", copy=";inComponentCopy;", move=";inComponentMove)
    
    return componentID
    
end function

function ECSInstanceType.RegisterSingletonComponent( _
        inComponentTypeSize as uinteger<32>, _
        inComponentName as zstring ptr, _
        inComponentData as any ptr = 0, _
        inComponentCtor as sub(as any ptr) = 0, _
        inComponentDtor as sub(as any ptr) = 0, _
        inComponentCopy as sub(as any ptr, as any ptr) = 0, _
        inComponentMove as sub(as any ptr, as any ptr) = 0) as ComponentIDType

    dim retID as ComponentIDType

    retID = this.RegisterComponent( _
        inComponentTypeSize, _
        inComponentName, _
        inComponentCtor, _
        inComponentDtor, _
        inComponentCopy, _
        inComponentMove)
    
    'Adding a component to itself makes it a singleton
    if inComponentData then
        this.AddComponent(retID, retID, inComponentTypeSize, inComponentData)
    else
        this.AddComponent(retID, retID)
    end if
    
    LogStat( _
        "Registered singleton component: ";*inComponentName; _
        ", size: ";inComponentTypeSize; _
        " ID: ";retID.ToString())
    LogTrace(!"\tctor=";inComponentCtor;", dtor=";inComponentDtor;", copy=";inComponentCopy;", move=";inComponentMove)
    
    return retID
    
end function

function ECSInstanceType.RegisterPairComponent( _
        inBaseComponentID as ComponentIDType, _
        inTargetID as EntityIDType, _
		inComponentTypeSize as uinteger<32> = 0, _
        inComponentCtor as sub(as any ptr) = 0, _
        inComponentDtor as sub(as any ptr) = 0, _
        inComponentCopy as sub(as any ptr, as any ptr) = 0, _
        inComponentMove as sub(as any ptr, as any ptr) = 0) as ComponentIDType
    
    dim componentID as ComponentIDType
	dim archetypeID as ArchetypeIDType
    dim baseComp as ComponentDescriptorType ptr
    dim tempComponentIDList as ComponentIDListType
    dim componentName as string
    
    'You should call FlushCommandBuffers before calling this
    
    componentID = this.GeneratePairComponent(inBaseComponentID, inTargetID)
    
	if (inComponentCopy <> 0) <> (inComponentMove <> 0) then
        'Dtor, copy, and move must show up together
        LogError(_
            !"If Dtor, Copy, or Move is provided, all 3 must be provided\n"; _
            "For pair component: "; _
			this.ComponentIDHumanReadable(inBaseComponentID);"_"; _
            inTargetID.ToString())
        
    end if
    
	if (inComponentCtor ORELSE inComponentDtor ORELSE _
		inComponentCopy ORELSE inComponentMove) ANDALSO inComponentTypeSize = 0 then
		
		LogError( _
			"Cannot have lifetime functions "; _
			"Ctor, Dtor, Copy, or Move on a null size pair component: "; _
			this.ComponentIDHumanReadable(inBaseComponentID);"_"; _
            inTargetID.ToString())
		
	end if
	
    'On defer, just return the component ID
    
    baseComp = this.ComponentDescriptorDictionary.KeyExistsGet(inBaseComponentID)
    if baseComp = 0 then
        
        'Must have created the base component first before making a pair
        LogWarn( _
            !"Cannot register pair component before registering the base component\n"; _
            "Creating pair out of: "; _
            this.ComponentIDHumanReadable(inBaseComponentID);", "; _
            inTargetID.ToString())
            
        return 0
        
    end if
    
    if this.EntityToLocationDictionary.KeyExists(componentID) ORELSE _
		this.CommandBuffer.DeferredPairComponents.KeyExists(componentID) then
        'Pair already exists
        return componentID
    end if
    
    if this.ComponentDescriptorDictionary.KeyExists(componentID) then
        LogError("Component collision: ";componentID.ToString())
    end if
    
    'Assign the base component the IsBase flag.
    'This allows proper querying for (base comp, any target)
    baseComp->IsBase = 1

    if baseComp->IsBase ANDALSO baseComp->IsPair then
        LogError( _
            "Base component set as both base and pair: ";_
            this.ComponentIDHumanReadable(inBaseComponentID))
    end if

    'Mash the names together with an underscore '_'
    componentName = baseComp->Name
    componentName = componentName & "_"
    componentName = componentName & inTargetID.ToString()

    'Create the entity with the combined IDs
	archetypeID = this.GetOrCreateArchetypeIDFromComponentList(tempComponentIDList)
	
    this.CreateEntityFromID(componentID, archetypeID)
    
    'Create the unique component descriptor
    dim tempComponent as ComponentDescriptorType = ComponentDescriptorType( _
        componentID, _
        inComponentTypeSize, _
        componentName, _
        inComponentCtor, _
        inComponentDtor, _
        inComponentCopy, _
        inComponentMove, _
        ComponentDescriptorType.IS_PAIR)
    
    'Capture the full details of the base and target IDs.
    'This will include generations
    tempComponent.BaseID = inBaseComponentID
    tempComponent.TargetID = inTargetID

    this.ComponentDescriptorDictionary[componentID] = tempComponent

    this.ComponentToArchetypeIDListDictionary[componentID] = _
        new DynamicArrayType(sizeof(ArchetypeIDType))
    
	this.PairToArchetypeIDListDictionary[componentID] = _
		new DynamicArrayType(sizeof(ArchetypeIDType))
	
	'Need to register the pair ID for caching here,
	'but the base ID will have already been added
	if this.ComponentToCachedQueryLIstDictionary.KeyExists(componentID) then
		LogError("Component already exists in cached query dictionary: "; _
			this.ComponentIDHumanReadable(componentID))
	end if
	
	this.ComponentToCachedQueryListDictionary[componentID] = _
		new DynamicArrayType(sizeof(QueryType ptr))
	
	if this.DeferMode then
		this.CommandBuffer.DeferredPairComponents[componentID] = 1
	end if
	
    LogTrace( _
        "Registered pair component: ";componentName; _
        ", size: ";0; _
		", base: ";tempComponent.BaseID.ToString(); _
		", target: ";tempComponent.TargetID.ToString(); _
        ", ID: ";componentID.ToString())
	LogTrace("    ctor=";inComponentCtor;", dtor=";inComponentDtor;", copy=";inComponentCopy;", move=";inComponentMove)
    
    return componentID

end function

sub ECSInstanceType.DeletePairComponent( _
		inPairID as ComponentIDType)

    if this.DeferMode then
        this.CommandBuffer.DeferDeletePairComponent(inPairID)
        return
    end if

	dim archetypeIDList as DynamicArrayType ptr ptr
	dim queryList as QueryType ptr

	archetypeIDList = this.PairToArchetypeIDListDictionary.KeyExistsGet(inPairID)
	if archetypeIDList = 0 then
		'Pair doesn't exist
		return
	end if
	
	LogTrace("Deleting pair component: ";this.ComponentIDHumanReadable(inPairID))

	if *archetypeIDList = 0 then
		LogError("Got null archetype list")
	end if

	dim savedArchetypeIDs as DynamicArrayType = DynamicArrayType(sizeof(ArchetypeIDType))

	'Need to make a copy of the list as DeleteArchetype
	'will modify the reference to the original list
	savedArchetypeIDs = **archetypeIDList

	'Undo the creation of the pair component
	
	'Delete entity relies on the component descriptor
	this.DeleteEntity(inPairID)
	
	'Delete all associated archetypes
	'This relies on the ComponentToArchetypeIDListDictionary to be intact
	FOR_IN(archetypeID, ArchetypeIDType, savedArchetypeIDs)
		this.DeleteArchetype(archetypeID)
	FOR_IN_NEXT
	
	'We can now delete the dictionary entries
	delete(this.ComponentToArchetypeIDListDictionary[inPairID])
	this.ComponentToArchetypeIDListDictionary.DeleteKey(inPairID)
	
	delete(this.PairToArchetypeIDListDictionary[inPairID])
	this.PairToArchetypeIDListDictionary.DeleteKey(inPairID)
	
	'Tell all cached queries that use this component they're
	'no longer being cached.
	
	'TODO: If the pair is deleted, is the query still lingering in the
	'cached query structure when keyed with the base compoenent?
	FOR_IN(query, QueryType ptr, *this.ComponentToCachedQueryListDictionary[inPairID])
		this.UnregisterCachedQuery(query)
	FOR_IN_NEXT
	
	'Remove the cached query list
	delete(this.ComponentToCachedQueryListDictionary[inPairID])
	this.ComponentToCachedQueryListDictionary.DeleteKey(inPairID)
	
	'Also delete anything potentially in the command buffer
	this.CommandBuffer.DeferredPairComponents.DeleteKey(inPairID)
	
	'Finally, delete the component descriptor
	this.ComponentDescriptorDictionary.DeleteKey(inPairID)
	
end sub

function ECSInstanceType.RegisterEvent( _
		inEventTypeSize as uinteger<32>, _
		inEventName as zstring ptr, _
		inEventDtor as sub(as any ptr) = 0) as EventIDType

	if (inEventDtor) ANDALSO inEventTypeSize = 0 then
		LogError( _
			"Cannot have lifetime function "; _
			"Dtor on a null size event: ";*inEventName)
	end if
	
	if inEventName = 0 then
		LogError("Event requires a name")
	else
		'Enforce unique event names
		FOR_IN(events, ECSEventQueueType, this.EventQueueList)
			if events.Name = *inEventName then
				LogError( _
					"Event name collision: ";*inEventName; _
					;" was already registered")
			end if
		FOR_IN_NEXT
	end if
	
	dim index as EventIDType
	dim eventPtr as ECSEventQueueType ptr

	index = this.EventQueueList.Reserve()
	eventPtr = cast(ECSEventQueueType ptr, @this.EventQueueList[index])

	eventPtr->Constructor( _
		*inEventName, _
		inEventTypeSize, _
		inEventDtor)
	
	eventPtr->ID = index
	
	'Push this event into our module's namespace
	dim byref module as ECSInstanceType.ModuleInfoType = _
		*cast(ECSInstanceType.ModuleInfoType ptr, @this.Modules[this.ModuleNamespaceIndex])
	dim eventIndex as uinteger = module.EventsList.Reserve(1)
	
	'Copy the string name in with namespace if needed
	dim byref _name as string = *cast(string ptr, @module.EventsList[eventIndex])
	_name = *inEventName
	
	LogStat( _
		"Registered event: ";eventPtr->Name; _
		", ID: ";eventPtr->ID; _
		", Size: ";inEventTypeSize)
	LogTrace(!"\tdtor=";inEventDtor)
	
	return index

end function

function ECSInstanceType.GetEventQueue( _
		inEventID as EventIDType) as ECSEventQueueType ptr
		
	return cast(ECSEventQueueType ptr, @this.EventQueueList[inEventID])
	
end function

sub ECSInstanceType.PreAllocateEvents( _
		inEventID as EventIDType, _
		inEventCount as uinteger)

	if inEventID <= 0 ORELSE inEventID > this.EventQueueList.Count then
		LogError("Tried to queue non-existant eventID: ";inEventID)
	end if
	
	if inEventCount = 0 then
		'Maybe this should return a warning
		return
	end if
	
	dim eventQueue as ECSEventQueueType ptr = this.GetEventQueue(inEventID)
	
	if eventQueue->Locked then
		LogError("Cannot pre-allocate a locked event queue")
	end if
	
	eventQueue->PreAllocate(inEventCount)
	
end sub

sub ECSInstanceType.EnqueueEvent( _
		inEventID as EventIDType, _
		inEventData as any ptr = 0)

	if inEventID <= 0 ORELSE inEventID > this.EventQueueList.Count then
		LogError("Tried to queue non-existant eventID: ";inEventID)
	end if
	
	dim eventQueue as ECSEventQueueType ptr = this.GetEventQueue(inEventID)
	
	if (inEventData = 0) <> (eventQueue->OneOffFlag = 1) then
		LogError( _
			!"Passed in data and event size do not match.\n"; _
			" Event: ";eventQueue->Name;!"\n"; _
			" Size: ";eventQueue->Events.Size;!"\n"; _
			" Data: ";inEventData)
	end if
	
	if eventQueue->Locked then

		LogTrace("Deferring queue event: ";eventQueue->Name)
		
		eventQueue->PushDeferredEvent(inEventData)
		
		return
		
	end if
	
	eventQueue->PushEvent(inEventData)

end sub

sub ECSInstanceType.EmptyEventQueue( _
		inEventID as EventIDType)

	dim eventQueue as ECSEventQueueType ptr = this.GetEventQueue(inEventID)
	
	if eventQueue->Locked then
		LogError("Cannot empty the queue of a locked event")
	end if
	
	eventQueue->Empty()

end sub

sub ECSInstanceType.AddComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType, _
        inComponentSize as integer = 0, _
        inComponentData as any ptr = 0)

    dim location as EntityLocationSpecifierType
    dim compDescriptor as ComponentDescriptorType ptr
    dim newComponentList as ComponentIDListType
    dim archetypeID as ArchetypeIDType
    dim archetypeRef as ArchetypeType ptr
    dim mapEdge as ArchetypeMapEdgeType ptr
    
    if this.DeferMode then
        
        LogTrace("Deferring add component: ";this.ComponentIDHumanReadable(inComponentID); _
        " to entity: ";inEntityID.ToString())
        
        this.CommandBuffer.DeferAddRemoveComponent( _
            inEntityID, _
            inComponentID, _
            ECSCommandBufferType.ADD_COMPONENT)
        
        if inComponentSize > 0 ANDALSO inComponentData <> 0 then
            this.DeferMoveComponent(inEntityID, inComponentID, inComponentSize, inComponentData)
        end if
        
        return
        
    end if
    
    compDescriptor = this.ComponentDescriptorDictionary.KeyExistsGet(inComponentID)
    if compDescriptor = 0 then
        LogError( _
            !"Adding component that was not registered.\n"; _
            "Entity: ";inEntityID.ToString();!"\n"; _
            "Component ID: ";inComponentID.ToString())
    end if
    
    archetypeRef = this.GetEntityActiveArchetype(inEntityID)
    
    if archetypeRef = 0 then
        'Entity doesn't exist
        LogError( _
            "Archetype not found for entity, does it exist? "; _
            inEntityID.ToString();!"\n"; _
            "Component: ";this.ComponentIDHumanReadable(inComponentID))
        return
    end if
    
    if inComponentData <> 0 ANDALSO _
       inComponentSize <> compDescriptor->Size then
    
        LogError( _
            !"Size differs from registered size: ";inComponentSize; _
            ", expected ";compDescriptor->Size;!"\n"; _
            "Entity: ";inEntityID.ToString();!"\n";_
            "Component: ";compDescriptor->ToString())
    end if
    
    if archetypeRef->ComponentIDDictionary.KeyExists(inComponentID) then
		if (inComponentSize = 0 ORELSE inComponentData = 0) then

			'Entity already has this component, and we're not supplying data
			return
			
		else
			
			'Entity already has this component, and now we're setting a new value
			this.DeferMoveComponent(inEntityID, inComponentID, inComponentSize, inComponentData)
			return
			
		end if
    end if
    
    mapEdge = archetypeRef->EdgeDictionary.KeyExistsGet(inComponentID)
    if mapEdge ANDALSO mapEdge->AddReference <> 0 then
        
        'We already have a reference to the archetype with the new component list
        archetypeID = mapEdge->AddReference

    else
        'Start with the current archetype's component list
        newComponentList = archetypeRef->ComponentIDList
        
        'Append the new component
        'If passed a duplicate, this will not change the list
        newComponentList.AddComponent(inComponentID)
        
        'Check if the archetype with that list exists, create if not
        archetypeID = this.ComponentListToArchetypeIDDictionary[newComponentList]

        if archetypeID = 0 then
            'Archetype does not exist, create it
            archetypeID = this.AddArchetype(newComponentList)
        end if
        
        'Add this archetype to the archetype graph
        archetypeRef->SetAddMapping(inComponentID, archetypeID)
        this.GetArchetypeByID(archetypeID)->SetRemoveMapping(inComponentID, archetypeRef->ID)
    end if
    
    'Move entity from old archetype to new one
    this.DeferMoveEntity(inEntityID, archetypeID)
    
    if inComponentSize > 0 ANDALSO inComponentData <> 0 then
        'If there's a component value to add, send it to the defer component list
        this.DeferMoveComponent(inEntityID, inComponentID, inComponentSize, inComponentData)
    end if
    'this.MoveEntity(inEntityID, archetypeID)
    
    LogTrace( _
        "Added component: ";this.ComponentIDHumanReadable(inComponentID); _
        " to entity: ";inEntityID.ToString())
    
end sub

sub ECSInstanceType.RemoveComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType)
    
    dim location as EntityLocationSpecifierType
    dim compDescriptor as ComponentDescriptorType ptr
    dim newComponentList as ComponentIDListType
    dim archetypeID as ArchetypeIDType
    dim archetypeRef as ArchetypeType ptr
    dim mapEdge as ArchetypeMapEdgeType ptr
    
    if this.DeferMode then
        
        LogTrace("Deferring remove component: ";this.ComponentIDHumanReadable(inComponentID); _
        " from entity: ";inEntityID.ToString())
        
        this.CommandBuffer.DeferAddRemoveComponent( _
            inEntityID, _
            inComponentID, _
            ECSCommandBufferType.REMOVE_COMPONENT)

        return
        
    end if
    
    compDescriptor = this.ComponentDescriptorDictionary.KeyExistsGet(inComponentID)
    if compDescriptor = 0 then
        LogError( _
            !"Removing component that was not registered.\n"; _
            "Entity: ";inEntityID.ToString();!"\n"; _
            "Component ID: ";inComponentID.ToString())
    end if
    
    archetypeRef = this.GetEntityActiveArchetype(inEntityID)
    
    if archetypeRef = 0 then
        'Entity doesn't exist
        LogError( _
            "Archetype not found for entity ";inEntityID.ToString();!"\n"; _
            "Component: ";this.ComponentIDHumanReadable(inComponentID))
        return
    end if
    
    if archetypeRef->ComponentIDDictionary.KeyExists(inComponentID) = 0 then
        'Entity does not have the supplied component
        return
    end if
    
    mapEdge = archetypeRef->EdgeDictionary.KeyExistsGet(inComponentID)
    if mapEdge ANDALSO mapEdge->RemoveReference <> 0 then
        
        'We already have a reference to the archetype with the new component list
        archetypeID = mapEdge->RemoveReference
        
    else
        newComponentList = archetypeRef->ComponentIDList
        
        'Remove the component from the list
        newComponentList.RemoveComponent(inComponentID)
        
        'Check if the archetype with that list exists, create if not
        archetypeID = this.ComponentListToArchetypeIDDictionary[newComponentList]
        
        if archetypeID = 0 then
            'Archetype does not exist, create it
            archetypeID = this.AddArchetype(newComponentList)
        end if
    
        archetypeRef->SetRemoveMapping(inComponentID, archetypeID)
        this.GetArchetypeByID(archetypeID)->SetAddMapping(inComponentID, archetypeRef->ID)
    end if
    
    'Move entity from old archetype to new one
    this.DeferMoveEntity(inEntityID, archetypeID)

    LogTrace( _
        "Removed component: ";this.ComponentIDHumanReadable(inComponentID); _
        " from entity: ";inEntityID.ToString())
    
end sub

function ECSInstanceType.HasComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType) as integer
    
    dim location as EntityLocationSpecifierType ptr

    'Check if entity exists
    location = this.EntityToLocationDictionary.KeyExistsGet(inEntityID)
    if location = 0 then
        return 0
    end if

    'Use the archetype dictionary component ID lookup
    return location->Archetype->ComponentIDDictionary.KeyExists(inComponentID) <> 0 
    
end function

function ECSInstanceType.GetComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType) as any ptr
    
    dim retComponentPtr as any ptr = 0
    
    dim location as EntityLocationSpecifierType ptr
    dim index as ushort ptr
    dim componentArray as DynamicArrayType ptr
    
    'Check if entity exists
    location = this.EntityToLocationDictionary.KeyExistsGet(inEntityID)
    if location = 0 then
        return 0
    end if
    
    'Check if component exists and get the index of the component array in the archetype
    index = location->Archetype->ComponentIDDictionary.KeyExistsGet(inComponentID)
    if index = 0 then
        return 0
    end if

    componentArray = location->Archetype->ComponentList[*index]
    
    retComponentPtr = DYNAMIC_ARRAY_CAST(any ptr, *componentArray, location->Index)

    return retComponentPtr

end function

function ECSInstanceType.GetSingletonComponent( _
        inComponentID as ComponentIDType) as any ptr

    return this.GetComponent(inComponentID, inComponentID)

end function

function ECSInstanceType.GetPairTarget( _
        inComponentID as ComponentIDType) as EntityIDType

    return inComponentID.TargetID

end function

sub ECSInstanceType.AddChildOf( _
        inChildID as EntityIDType, _
        inParentID as EntityIDType)
    
    dim childOfPair as ComponentIDType
    dim depth as integer<32> = 1
    dim parentArch as ArchetypeType ptr
    dim parentPairID as PairComponentContainerType ptr
    dim compDescriptor as ComponentDescriptorType ptr
    
	if this.DeferMode then
		this.CommandBuffer.DeferAddChildOf(inChildID, inParentID)
		return
	end if
	
    childOfPair = this.RegisterPairComponent(this.ChildOfTag, inParentID)
    
    parentArch = this.GetEntityActiveArchetype(inParentID)
    if parentArch = 0 then
        LogError( _
            !"Parent has null archetype.\n"; _
            "Parent ID: ";inParentID.ToString(); _
            " Child ID : ";inChildID.ToString())
    end if

    'Obtain the depth of the parent ID, if applicable
    parentPairID = parentArch->BaseToPairDictionary.KeyExistsGet(this.ChildOfTag)
    if parentPairID then
        
        compDescriptor = this.ComponentDescriptorDictionary.KeyExistsGet(parentPairID->PairID)
        if compDescriptor then
        
            'Parent is a child of another entity
            depth = compDescriptor->SortIndex + 1
            
        else
            LogError( _
                !"Got null component descriptor for parent.\n"; _
                "Parent ID: ";inParentID.ToString(); _
                "Child ID : ";inChildID.ToString())
        end if
    end if
    
    LogTrace( _
		"Adding: ";inChildID.ToString(); _
		" as ChildOf: ";inParentID.ToString(); _
		" with depth: ";depth)
    
    this.AssignComponentSortIndex(childOfPair, depth)
    this.AddComponent(inChildID, childOfPair)
    
end sub

function ECSInstanceType.HasChildren( _
        inEntityID as EntityIDType) as integer
    
    dim pairComponent as ComponentIDType
    
    pairComponent = this.GeneratePairComponent(this.ChildOfTag, inEntityID)
    
    return this.ComponentToArchetypeIDListDictionary.KeyExists(pairComponent)
    
end function

function ECSInstanceType.HasParent( _
        inEntityID as EntityIDType) as integer
    
    dim archetypeRef as ArchetypeType ptr
    
    archetypeRef = this.GetEntityActiveArchetype(inEntityID)
    if archetypeRef = 0 then
        LogError("Got null archetype for entity: ";inEntityID.ToString())
        return 0
    end if
    
    return archetypeRef->BaseToPairDictionary.KeyExists(this.ChildOfTag)
    
end function

function ECSInstanceType.GetParentPairContainer( _
        inEntityID as EntityIDType) as PairComponentContainerType

    dim retPair as PairComponentContainerType = (0, 0)
    dim archetypeRef as ArchetypeType ptr
    dim pairID as PairComponentContainerType ptr
    
    archetypeRef = this.GetEntityActiveArchetype(inEntityID)
    if archetypeRef = 0 then
        LogError("Got null archetype for entity: ";inEntityID.ToString())
        return retPair
    end if
    
    pairID = archetypeRef->BaseToPairDictionary.KeyExistsGet(this.ChildOfTag)
    if pairID = 0 then
        return retPair
    end if
    
    return *pairID
    
end function

function ECSInstanceType.GetParent( _
        inEntityID as EntityIDType) as EntityIDType

    return this.GetParentPairContainer(inEntityID).TargetID

end function

sub ECSInstanceType.ChangeParent( _
		inChildID as EntityIDType, _
		inNewParentID as EntityIDType)
	
	dim oldParentPair as ComponentIDType
	
	oldParentPair = this.GetParentPairContainer(inChildID).PairID
	
	if oldParentPair.ID <> 0 then
		this.RemoveComponent(inChildID, oldParentPair)
	end if
	
	this.AddChildOf(inChildID, inNewParentID)
	
end sub

function ECSInstanceType.IsAncestorOf( _
		inAncestorID as EntityIDType, _
		inDescendentID as EntityIDType) as integer
	
	dim parentID as EntityIDType
	
	parentID = this.GetParent(inDescendentID)
	
	while parentID.ID <> 0

		if parentID = inAncestorID then
			return 1
		end if
		
		parentID = this.GetParent(parentID)
	
	wend
	
	return 0
	
end function

sub ECSInstanceType.AssignComponentSortIndex( _
        inComponentID as ComponentIDType, _
        inSortIndex as integer<32>)
    
    if this.ComponentDescriptorDictionary.KeyExists(inComponentID) = 0 then
    
        LogWarn( _
            !"Cannot assign sort index to non-existent component\n"; _
            "Component: ";this.ComponentIDHumanReadable(inComponentID))
        
        return
    end if
    
    dim byref compDescriptor as ComponentDescriptorType = _
        this.ComponentDescriptorDictionary[inComponentID]
    
    compDescriptor.SortIndex = inSortIndex

end sub

function ECSInstanceType.GetComponentSortIndex( _
        inComponentID as ComponentIDType) as integer<32>

    if this.ComponentDescriptorDictionary.KeyExists(inComponentID) = 0 then
        'Log warning?
        return 0
    end if

    return this.ComponentDescriptorDictionary[inComponentID].SortIndex

end function

sub ECSInstanceType.CopyComponentData( _
        toPointer as any ptr, _
        fromPointer as any ptr, _
        inComponentID as ComponentIDType)

    if toPointer = fromPointer then
        return
    end if
    
    dim byref compDesc as ComponentDescriptorType = _
        this.ComponentDescriptorDictionary[inComponentID]
    
    'If there's a destructor, clear the destination first
    if compDesc.Dtor then
        (compDesc.Dtor)(toPointer)
    end if

    'If there's a defined copy function, use it
    if compDesc.Copy then
        (compDesc.Copy)(toPointer, fromPointer)
        return
    end if
    
    'Otherwise, memcpy
    dim size as uinteger<32> = compDesc.Size

    memcpy(toPointer, fromPointer, size)

end sub

sub ECSInstanceType.MoveComponentData( _
        toPointer as any ptr, _
        fromPointer as any ptr, _
        inComponentID as ComponentIDType)

    if toPointer = fromPointer then
        return
    end if
    
    dim byref compDesc as ComponentDescriptorType = _
        this.ComponentDescriptorDictionary[inComponentID]
    
    'If there's a defined move function, use it
    if compDesc.Move then
        (compDesc.Move)(toPointer, fromPointer)
        return
    end if
    
    'Otherwise, memcpy assuming this data can be safely written over
    dim size as uinteger<32> = compDesc.Size

    memcpy(toPointer, fromPointer, size)

end sub

sub ECSInstanceType.AddArchetypeToComponentQueryPool( _
        archetypeRef as ArchetypeType ptr, _
        componentID as ComponentIDType)
    
    dim archetypeIDList as DynamicArrayType ptr
    
    archetypeIDList = this.ComponentToArchetypeIDListDictionary[componentID]
    archetypeIDList->PushUDT(@archetypeRef->ID)

end sub

sub ECSInstanceType.RemoveArchetypeFromComponentQueryPool( _
        archetypeRef as ArchetypeType ptr, _
        componentID as ComponentIDType)
    
    dim archetypeIDList as DynamicArrayType ptr
    
    archetypeIDList = this.ComponentToArchetypeIDListDictionary[componentID]
    
    'Linear search for the ID in the list
    'Archetypes more recently added are more likely to be disabled
    'This is due to the fact that some archetypes are just steps
    'to another archetype creation when components are added
    'individually to an entity. Thus, step backward
    'Hopefully this isn't too expensive
	dim i as integer
    for i = archetypeIDList->Count-1 to 0 step -1
        
        if *DYNAMIC_ARRAY_CAST(ArchetypeIDType ptr, *archetypeIDList, i) = archetypeRef->ID then
            archetypeIDList->Remove(i)
            exit for
        end if
    next
    
	if i < 0 then
		LogWarn( _
			!"Could not remove archetype from component query pool: archetype was not found.\n" _
			"Archetype ID: ";archetypeRef->ID)
	end if
	
end sub

sub ECSInstanceType.RemoveArchetypeFromQueryPool( _
        archetypeRef as ArchetypeType ptr)
    
    dim compID as ComponentIDType
	
    for i as integer = 0 to archetypeRef->ComponentIDList.Count-1
        
        compID = archetypeRef->ComponentIDList[i]
        
        this.RemoveArchetypeFromComponentQueryPool(archetypeRef, compID)
        
        dim byref compDescriptor as ComponentDescriptorType = _
                this.ComponentDescriptorDictionary[compID]
		
		this.InvalidateCachedQueries(compID)
		
        if compDescriptor.IsPair then
            'If the component is a pair component, remove the base
            dim baseComponentID as ComponentIDType
            baseComponentID.ID = compID.EntityID
            
            this.RemoveArchetypeFromComponentQueryPool( _
                archetypeRef, baseComponentID)
			
			'Need to also invalidate any query that queries on
			'the base of this pair
			this.InvalidateCachedQueries(baseComponentID)
            
        end if
        
    next
    
end sub

sub ECSInstanceType.InvalidateCachedQueries( _
		componentID as ComponentIDType)
	
	dim queryList as DynamicArrayType ptr = _
		this.ComponentToCachedQueryListDictionary[componentID]
	
	if queryList = 0 then
		'This really shouldn't ever be 0
		LogError(!"Cached query list not maintained properly, "; _
			"encountered null cached query list for component: "; _
			this.ComponentIDHumanReadable(componentID))
		return
	end if
	
	'Notify each query that it will need to be updated
	FOR_IN(query, QueryType ptr, *queryList)
		query->CachedInfo.UseExistingData = 0
	FOR_IN_NEXT
	
end sub

sub ECSInstanceType.RegisterArchetypeUsingPair( _
		inPairID as ComponentIDType, _
		inArchetypeID as ArchetypeIDType)
	
	dim archIDList as DynamicArrayType ptr
	archIDList = this.PairToArchetypeIDListDictionary[inPairID]
	if archIDList = 0 then
		LogError("Got null archetype ID list")
	end if
	archIDList->Push(inArchetypeID)
	
end sub
	
sub ECSInstanceType.UnregisterArchetypeUsingPair( _
		inPairID as ComponentIDType, _
		inArchetypeID as ArchetypeIDType)
	
	dim archetypeIDs as DynamicArrayType ptr ptr
	
	archetypeIDs = this.PairToArchetypeIDListDictionary.KeyExistsGet(inPairID)
	if archetypeIDs = 0 then
		return
	end if

	DYNAMICARRAY_FOREACH_START(**archetypeIDs, i, archetypeID, ArchetypeIDType)

		if archetypeID = inArchetypeID then
			(*archetypeIDs)->Remove(i)
			exit for
		end if
	
	DYNAMICARRAY_FOREACH_NEXT
	
end sub

function ECSInstanceType.AddEntityToArchetype( _
        inEntityID as EntityIDType, _
        inArchetypeID as ArchetypeIDType) as EntityLocationSpecifierType

    dim retLocation as EntityLocationSpecifierType
    dim archetypeRef as ArchetypeType ptr
    dim archetypeIDList as DynamicArrayType ptr
    dim compID as ComponentIDType

    archetypeRef = this.GetArchetypeByID(inArchetypeID)
    
    if archetypeRef->LockedFlag <> 0 then
        LogWarn( _
            "Add: Modifying locked archetype: "; _
            archetypeRef->ID;": ";archetypeRef->LockedFlag)
    end if
    
    'Generate the location specifier
    retLocation.Archetype = archetypeRef
    retLocation.Index = archetypeRef->EntityList.Count
    
    LogTrace("Adding entity: ";inEntityID.ToString();" to archetype: ";inArchetypeID)
    
    'Add the entity to the archetype
    with (*retLocation.Archetype)
        
        for i as integer = 0 to .ComponentIDList.Count - 1
            
            compID = .ComponentIDList[i]
            
            dim compIndex as uinteger = .ComponentList[i]->Reserve()
            
            dim byref compDescriptor as ComponentDescriptorType = _
                this.ComponentDescriptorDictionary[compID]
            
            'Call the constructor if defined
            if compDescriptor.Ctor then
                (compDescriptor.Ctor)(DYNAMIC_ARRAY_CAST(any ptr, *(.ComponentList[i]), compIndex))
            end if
			
            if .EntityList.Count = 0 then
                'Push the archetype ID into the component ID to archetype ID list
                'This ensures only archetypes with entities are iterated over
                'when querying for components
                this.AddArchetypeToComponentQueryPool(archetypeRef, compID)
                
				this.InvalidateCachedQueries(compID)
				
                if compDescriptor.IsPair then
                    'If the component is a pair component, push the base
                    dim baseComponentID as ComponentIDType
                    baseComponentID.ID = compID.EntityID
                    
                    this.AddArchetypeToComponentQueryPool(archetypeRef, baseComponentID)
					
					this.InvalidateCachedQueries(baseComponentID)
					
                end if

            end if
            
        next
        
        .EntityList.Push(cast(uinteger<64>, inEntityID))
        
    end with
    
    return retLocation
    
end function

sub ECSInstanceType.DeleteEntityFromArchetype( _
        byref inLocation as EntityLocationSpecifierType)

    dim movedEntityIndex as integer
    dim movedEntityID as EntityIDType
    dim archetypeIDList as DynamicArrayType ptr
    dim compID as ComponentIDType
    
    LogTrace( _
        "Removing entity: ";DYNAMIC_ARRAY_CAST(EntityIDType ptr, _
            inLocation.Archetype->EntityList,_
            inLocation.Index)->ToString(); _
        " from archetype: ";inLocation.Archetype->ID)
    
    if inLocation.Archetype->LockedFlag <> 0 then
        LogWarn( _
            "Delete: Modifying locked archetype: "; _
            inLocation.Archetype->ID;": ";inLocation.Archetype->LockedFlag)
    end if
    
    'Remove the entity from the archetype
    with (*inLocation.Archetype)
        
        'Remove each component item from the component arrays
        for i as integer = 0 to .ComponentIDList.Count - 1
            
            compID = .ComponentIDList[i]
            
            dim byref compDescriptor as ComponentDescriptorType = _
                this.ComponentDescriptorDictionary[compID]
            
            if compDescriptor.Dtor then
                (compDescriptor.Dtor)(DYNAMIC_ARRAY_CAST(any ptr, *.ComponentList[i], inLocation.Index))
            end if
            
            .ComponentList[i]->Remove(inLocation.Index)
        next
        
        'Remove the entity from the entity list
        movedEntityIndex = .EntityList.Remove(inLocation.Index)

    end with

    'Swap the index of the moved entity with the old one
    'if there's still something in the list
    if movedEntityIndex >= 0 then
        
        movedEntityID = _
            *DYNAMIC_ARRAY_CAST(EntityIDType ptr, inLocation.Archetype->EntityList, movedEntityIndex)
        
        if movedEntityID.ID = 0 then
            LogError("Hit entity ID 0 while moving entity index: ";movedEntityIndex)
        end if
        
        'Update the index of the moved entity
        this.EntityToLocationDictionary[movedEntityID].Index = movedEntityIndex
        
    end if
    
    'Check if we have entities left in the archetype
    if inLocation.Archetype->EntityList.Count > 0 then
        return
    end if
    
    'No more entities left in this archetype
    'Remove the archetype ID from the component ID to archetype ID lists
    'This ensures only archetypes with entities are iterated over
    'when querying for components
    this.RemoveArchetypeFromQueryPool(inLocation.Archetype)
    
    'This may be un-commented to test deleting archetypes
    'to see the memory savings/execution cost
    'Remember to comment out the above line though (RemoveArchetypeFromQueryPool)
    'this.DeleteArchetype(inLocation.Archetype->ID)
    
end sub

sub ECSInstanceType.RemoveEntityID( _
        inEntityID as EntityIDType)
    
    dim incrementedID as EntityIDType
	dim compDescriptor as ComponentDescriptorType ptr
	
    'Increase the entity ID's generation
    incrementedID = inEntityID
    incrementedID.Generation = incrementedID.Generation + 1

	compDescriptor = this.ComponentDescriptorDictionary.KeyExistsGet(inEntityID)
	if compDescriptor ANDALSO compDescriptor->IsPair then
		'Pair components do not have a generation so we don't need
		'to recycle them
	else
		'Push the incremented ID into the grab bag
		this.DeletedEntityIDList.PushUDT(@incrementedID)
	end if
    
    'Remove the entity from the entity -> location map
    this.EntityToLocationDictionary.DeleteKey(inEntityID)
    
    'Remove the entityID from the defer dictionary
    'NO-OP if the entityID does not exist in it
    this.CommandBuffer.DeferMoveEntityDictionary.DeleteKey(inEntityID)

end sub

sub ECSInstanceType.DeleteChildrenRecursive( _
        inEntityID as EntityIDType)
    
    'Note that deleting children here actually means deleting the archetypes
    'that hold the children.  Child entities are NOT deleted one at a time.
    
    'TODO: There's a bug here where the entityID is not being recycled properly
    dim pairComponent as ComponentIDType
    dim archetypeList as DynamicArrayType ptr ptr
    
    dim archetypeRef as ArchetypeType ptr
	dim savedArchetypeIDs as DynamicArrayType = DynamicArrayType(sizeof(ArchetypeIDType))

    pairComponent = this.GeneratePairComponent(this.ChildOfTag, inEntityID)
    
    archetypeList = this.PairToArchetypeIDListDictionary.KeyExistsGet(pairComponent)
    if archetypeList = 0 then
        'No children
        return
    end if
    
    if *archetypeList = 0 then
        LogError("Null component list hit")
    end if
	
	'We need to save the IDs separately as **archetypeList is referencing 
	'a structure that will be modified when calling DeleteArchetype
	savedArchetypeIDs = **archetypeList
	
    FOR_IN(archetypeID, ArchetypeIDType, **archetypeList)

        archetypeRef = this.GetArchetypeByID(archetypeID)
        
        FOR_IN(entID, EntityIDType, archetypeRef->EntityList)
            this.DeleteChildrenRecursive(entID)
        FOR_IN_NEXT

    FOR_IN_NEXT

	this.DeletePairComponent(pairComponent)
	
	'FOR_IN(archetypeID, ArchetypeIDType, savedArchetypeIDs)
	'	this.DeleteArchetype(archetypeID)
	'FOR_IN_NEXT
	
end sub

sub ECSInstanceType.DeleteEntity( _
        inEntityID as EntityIDType)

    dim location as EntityLocationSpecifierType ptr
    dim incrementedID as EntityIDType
    
	if this.DeferMode then
        
        LogTrace("Deferring delete entity: ";inEntityID.ToString())
		
        this.CommandBuffer.DeferDeleteEntity(inEntityID)
		
        return
        
    end if
	
    'Check if entity exists
    location = this.EntityToLocationDictionary.KeyExistsGet(inEntityID)
    if location = 0 then
        return
    end if

    this.DeleteEntityFromArchetype(*location)
    
    this.RemoveEntityID(inEntityID)
    
    if this.HasChildren(inEntityID) = 0 then
        'No children to bother with
        return
    end if
    
    'Delete all children of this entity
    this.DeleteChildrenRecursive(inEntityID)
    
end sub

sub ECSInstanceType.MoveEntity( _
        inEntityID as EntityIDType, _
        inNewArchetypeID as ArchetypeIDType)

    dim newLocation as EntityLocationSpecifierType
    dim newComponentIndex as ushort ptr
    
    dim movedEntity as EntityIDType
    
    dim oldLocation as EntityLocationSpecifierType ptr
    
    dim componentDescriptor as ComponentDescriptorType ptr

    'Get a pointer to the old location for reference and updating
    oldLocation = @this.EntityToLocationDictionary[inEntityID]
    
    if oldLocation = 0 then
        LogError("Old location was null. Was the entity already moved?")
    end if
    
    if oldLocation->Archetype = 0 then
        LogError("Old location archetype was null?")
    end if
    
    if oldLocation->Archetype = this.GetArchetypeByID(inNewArchetypeID) then
        'No need to move between the same archetype
        return
    end if
    
    'Reserve space for the entity's new location
    newLocation = this.AddEntityToArchetype(inEntityID, inNewArchetypeID)
    
    'Copy over the old data to the new entity
    with *(oldLocation->Archetype)

        'Loop over each component ID
        for i as integer = 0 to .ComponentIDList.Count - 1
            
            'Get the column index in the new archetype
            newComponentIndex = _
                newLocation.Archetype->ComponentIDDictionary.KeyExistsGet(.ComponentIDList[i])
            if newComponentIndex = 0 then
                'Skip components that do not exist in the target archetype
                continue for
            end if
            'Move the old component into the new component space.
            'This transfers ownership
            'TODO: clean this up?  Make it more readable?
            this.MoveComponentData( _
                @(*newLocation.Archetype->ComponentList[*newComponentIndex])[newLocation.Index], _
                @(*oldLocation->Archetype->ComponentList[i])[oldLocation->Index], _
                .ComponentIDList[i])

        next

        'Remove the entity from the old archetype
		'TODO: Optimize
		'DeleteEntityFromArchetype calls the destructor on the components
		'that were moved.  Strictly speaking, we don't need to do that.
		'This would require calling the destructor in the above loop where
		'the component doesn't exist in the target archetype, then skipping
		'component destruction in DeleteEntityFromArchetype
        this.DeleteEntityFromArchetype(*oldLocation)

    end with
    
    'Set the entity's new location
    *oldLocation = newLocation

end sub

sub ECSInstanceType.DeferMoveEntity( _
        inEntityID as EntityIDType, _
        inArchetypeID as ArchetypeIDType)
    
    dim archetypeRef as ArchetypeType ptr
    
    archetypeRef = this.GetArchetypeByID(inArchetypeID)

    this.CommandBuffer.DeferMoveEntity(inEntityID, archetypeRef)
    
end sub

sub ECSInstanceType.DeferMoveComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType, _
        inComponentSize as integer, _
        inComponentData as any ptr)

    dim size as uinteger<32> = inComponentSize
    
    dim srcPtr as any ptr
    dim dstPtr as any ptr
    
    dim neededSize as integer
    
    dim headerSize as integer = _
        sizeof(inEntityID) + sizeof(inComponentID) + sizeof(uinteger<32>)
    
    if inComponentData = 0 then
        LogError("Component data was null")
    end if
    
    srcPtr = inComponentData
    dstPtr = this.CommandBuffer.DeferMoveComponent( _
        inEntityID, _
        inComponentID, _
        inComponentSize)
    
    LogTrace(_
            !"Deferring component move: ("; _
            "entity=";inEntityID.ToString(); _
            ", component=";this.ComponentIDHumanReadable(inComponentID); _
            ", size=";size; _
            ", srcPtr=";srcPtr; _
            ", dstPtr=";dstPtr;")")
    
    this.CopyComponentData(dstPtr, srcPtr, inComponentID)
    
    return
    
end sub

sub ECSInstanceType.FlushCommandBuffer()

	if this.DeferMode then
		LogError("Flushing command buffer in defer mode?")
	end if
	
    if this.CommandBuffer.HasCommands = 0 then
        return
    end if
    
    LogTrace("Flushing command buffer: ";this.CommandBuffer.HasCommands;" commands")
	
	FOR_IN(createEntityArgs, ECSCommandBufferType.CreateEntityContainerType, this.CommandBuffer.DeferCreateEntityList)
		LogTrace("Creating entity: ";createEntityArgs.EntityID.ToString())
		this.CreateEntityFromID(createEntityArgs.EntityID, createEntityArgs.ArchetypeID)
	FOR_IN_NEXT
	
	FOR_IN(addChildOfArgs, ECSCommandBufferType.AddChildOfArgsType, this.CommandBuffer.DeferAddChildOfList)
		LogTrace("Adding ";addChildOfArgs.ChildID.ToString();" as child of ";addChildOfArgs.ParentID.ToString())
		this.AddChildOf(addChildOfArgs.ChildID, addChildOfArgs.ParentID)
	FOR_IN_NEXT
	
	LogTrace("Running add/remove components")
    FOR_IN(args, ECSCommandBufferType.AddRemoveComponentArgsType, this.CommandBuffer.DeferAddRemoveComponentList)
        
        if args.EntityID = 0 then
            LogError("Add/remove component called on null entity")
        end if
        
        select case as const args.Command
            case ECSCommandBufferType.ADD_COMPONENT
                this.AddComponent(args.EntityID, args.ComponentID, 0, 0)
            case ECSCommandBufferType.REMOVE_COMPONENT
                this.RemoveComponent(args.EntityID, args.ComponentID)
            case else
                LogError( _
                    !"Corrupted defer add/remove component list, command not set properly\n"; _
                    "Command: ";args.Command)
        end select
        
    FOR_IN_NEXT
    
    DICTIONARY_FOREACH_START(this.CommandBuffer.DeferMoveEntityDictionary, key, value)
        this.MoveEntity(*key, (*value)->ID)
    DICTIONARY_FOREACH_NEXT

    this.FlushMoveComponents()
	
	FOR_IN(entityID, EntityIDType, this.CommandBuffer.DeferDeleteEntityList)
		this.DeleteEntity(entityID)
	FOR_IN_NEXT

    FOR_IN(pairID, ComponentIDType, this.CommandBuffer.DeferDeletePairComponentList)
        this.DeletePairComponent(pairID)
    FOR_IN_NEXT
	
    this.CommandBuffer.Empty()
    
    LogTrace("Done flushing command buffer")
    
end sub

sub ECSInstanceType.FlushMoveComponents()

    dim tempEntityID as EntityIDType ptr
    dim tempComponentID as ComponentIDType ptr
    dim dataSize as uinteger
    dim size as uinteger<32> ptr
    dim dataPointer as any ptr
    dim index as uinteger = 0
    
    dim componentArray as DynamicArrayType ptr
    dim location as EntityLocationSpecifierType ptr
    dim lastEntityID as EntityIDType
    dim componentIndex as ushort ptr
    
    dim moveContainer as ECSCommandBufferType.MoveComponentContainerType ptr
    
    'Run through the list of move commands and execute them
    
    lastEntityID.ID = -1
    
    with this.CommandBuffer.DeferMoveComponentList

        while index < .Count
            
            moveContainer = cast(ECSCommandBufferType.MoveComponentContainerType ptr, @this.CommandBuffer.DeferMoveComponentList[index])
            index += sizeof(ECSCommandBufferType.MoveComponentContainerType)
            
            dim byref compDesc as ComponentDescriptorType = _
                this.ComponentDescriptorDictionary[moveContainer->ComponentID]
            
            if moveContainer->EntityID = lastEntityID then
                'Use the last location and save a dictionary lookup
                'This should never be called on the first loop
            else
                
                'Check if entity exists
                location = this.EntityToLocationDictionary.KeyExistsGet(moveContainer->EntityID)
                if location = 0 then
                    'Doesn't exist, destroy the data, increment the index and move on
                    
                    if compDesc.Dtor then
                        LogTrace( _
                            "Calling dtor on command with non-existent entity: "; _
                            moveContainer->EntityID.ToString())
                        (compDesc.Dtor)(@this.CommandBuffer.DeferMoveComponentList[index])
                        return
                    end if
                    
                    index += moveContainer->Size

                    continue while
                end if
                
            end if
            
            'Copy the last entityID in the case we already have them
            'It's likely the case that an entity has multiple components attached
            'to it sequentially, and the overhead of this is small.
            lastEntityID = moveContainer->EntityID
            
            'Check if component exists in the archetype and get the index of the component array in the archetype
            componentIndex = location->Archetype->ComponentIDDictionary.KeyExistsGet(moveContainer->ComponentID)
            if componentIndex = 0 then
    
                if compDesc.Dtor then
                    LogTrace("Calling dtor on command with non-existent component: ";tempComponentID->ToString())
                    (compDesc.Dtor)(@this.CommandBuffer.DeferMoveComponentList[index])
                    return
                end if
                
                index += moveContainer->Size
                
                continue while
            end if
    
            'Get the component array for the target component
            componentArray = location->Archetype->ComponentList[*componentIndex]
            
            'Get the pointer to the component location for our entity
            dataPointer = DYNAMIC_ARRAY_CAST(any ptr, *componentArray, location->Index)
            
            LogTrace(_
                !"Executing component move: ("; _
                "entity=";moveContainer->EntityID.ToString(); _
                ", component=";this.ComponentIDHumanReadable(moveContainer->ComponentID); _
                ", size=";moveContainer->Size; _
                ", srcPtr=";dataPointer; _
                ", dstPtr=";@this.CommandBuffer.DeferMoveComponentList[index]; _
				")")
            
            if compDesc.Dtor then
                'We need to call the destructor on the current component as
                'it's going to be overwritten                
                (compDesc.Dtor)(dataPointer)
            end if
            
            this.MoveComponentData( _
                dataPointer, _
                @this.CommandBuffer.DeferMoveComponentList[index], _
                moveContainer->ComponentID)
    
            index +=  moveContainer->Size
        wend
        
    end with

end sub

sub ECSInstanceType.DestructArchetypeComponents( _
		inArchetypeRef as ArchetypeType ptr)
	
	dim compListIndex as ushort
    dim componentDataList as DynamicArrayType ptr
	
	dim dataPointer as any ptr
	
	'Run the destructors on the component lists, if applicable
    for i as integer = 0 to inArchetypeRef->ComponentIDList.Count - 1
        
        dim byref compDescriptor as ComponentDescriptorType = _
            this.ComponentDescriptorDictionary[inArchetypeRef->ComponentIDList[i]]
        
        if compDescriptor.Dtor then
            
            if inArchetypeRef->ComponentIDDictionary.KeyExists(inArchetypeRef->ComponentIDList[i]) = 0 then
                LogError("Running destructor on invalid component id: ";inArchetypeRef->ComponentIDList[i].ToString())
            end if
            
            compListIndex = inArchetypeRef->ComponentIDDictionary[inArchetypeRef->ComponentIDList[i]]
            componentDataList = inArchetypeRef->ComponentList[compListIndex]
            
            for j as integer = 0 to componentDataList->Count - 1
                'Call the destructor on each component data item
                dataPointer = DYNAMIC_ARRAY_CAST(any ptr, *componentDataList, j)
                (compDescriptor.Dtor)(dataPointer)
            next
            
        end if
		
    next
	
end sub

function ECSInstanceType.GetNextArchetypeID() as ArchetypeIDType
    
    dim archIDRef as ArchetypeIDType
    dim retCount as ArchetypeIDType
    
    if this.DeletedArchetypeIDList.Count > 0 then
        
        'Grab from the grab bag
        archIDRef = *DYNAMIC_ARRAY_CAST( _
            ArchetypeIDType ptr, _
            this.DeletedArchetypeIDList, _
            this.DeletedArchetypeIDList.Count-1)
            
        this.DeletedArchetypeIDList.Remove(this.DeletedArchetypeIDList.Count-1)
            
        return archIDRef
    end if
    
    retCount = this.ArchetypeList.Count
    
    this.ArchetypeList.Reserve()
    
    return retCount

end function

function ECSInstanceType.AddArchetype( _
        byref inComponentList as ComponentIDListType) as ArchetypeIDType

    dim ID as ArchetypeIDType
    dim tempArchetype as ArchetypeType ptr

    'Array of individual component sizes
    dim componentSizes(inComponentList.Count-1) as uinteger<32>
    
    'Generate the archetype ID
    ID = this.GetNextArchetypeID()
    'ID = this.ArchetypeList.Count

    'Copy the sizes of the corresponding components into a list
    for i as integer = 0 to ubound(componentSizes)
        
        dim byref compDescriptor as ComponentDescriptorType = _
            this.ComponentDescriptorDictionary[inComponentList[i]]
        
        'Gather the size of each component into an array for archetype creation
        componentSizes(i) = compDescriptor.Size
        
        'The new archetype is not pushed into the componentID to archetype list
        'until it gets an entity
        
        'dim archetypeIDList as DynamicArrayType ptr
        'archetypeIDList = this.ComponentToArchetypeIDListDictionary[inComponentList[i]]
        'archetypeIDList->Push(ID)
    next
    
    'Create the new archetype
    tempArchetype = new ArchetypeType(ID, inComponentList, componentSizes())
    
    'Add the base -> pair mapping
    'TODO: move this into the above loop?
    for i as integer = 0 to ubound(componentSizes)
        
        dim byref compDescriptor as ComponentDescriptorType = _
            this.ComponentDescriptorDictionary[inComponentList[i]]
        
        if compDescriptor.IsPair then
            'If a component is a pair, add a map from Base ID to Pair Component ID
            'The Base component does NOT have to exist in the archetype
            
            dim baseID as ComponentIDType
            baseID.ID = inComponentList[i].EntityID
            
            dim pairContainer as PairComponentContainerType
            pairContainer.TargetID = compDescriptor.TargetID
            pairContainer.PairID = inComponentList[i]
           
            tempArchetype->BaseToPairDictionary[baseID] = pairContainer
			
			this.RegisterArchetypeUsingPair(pairContainer.PairID, ID)
			
        end if

    next
    
    'Copy the pointer, do not delete tempArchetype here
    *DYNAMIC_ARRAY_CAST(ArchetypeType ptr ptr, this.ArchetypeList, ID) = tempArchetype
    'this.ArchetypeList.PushUDT(@tempArchetype)

    'Shove the new archetype ID into our componentList to archetype id map
    this.ComponentListToArchetypeIDDictionary[inComponentList] = ID
	
	LogTrace("Created archetype: ";ID)
	
    return ID
        
end function

sub ECSInstanceType.DeleteArchetype( _
        inArchetypeID as ArchetypeIDType)

    dim archetypeRef as ArchetypeType ptr
    dim otherArchetype as ArchetypeType ptr
    dim otherEdge as ArchetypeMapEdgeType ptr
    
    dim archetypeListRef as ArchetypeType ptr ptr
    
    dim location as EntityLocationSpecifierType ptr
    dim incrementedID as EntityIDType
    
    dim dataPointer as any ptr
    
	if inArchetypeID = 0 then
		LogError("Attempted to delete the null archetype!")
	end if

    archetypeRef = this.GetArchetypeByID(inArchetypeID)
    
	if archetypeRef = 0 then
        'Log warning maybe?
        LogError("Got null archetype pointer")
        return
    end if
	
	if archetypeRef = ARCHETYPE_TOMBSTONE then
		LogError("Deleting tombstone archetype?")
		return
	end if
	
    'Remove this archetype from the archetype graph
    DICTIONARY_FOREACH_START(archetypeRef->EdgeDictionary, compID, edge)

        if edge->AddReference then
            'Remove the other archetype's mapping to us
            otherArchetype = this.GetArchetypeByID(edge->AddReference)
            otherArchetype->SetRemoveMapping(*compID, 0)
            
            'This is a doubly linked list basically, so we need to
            'possibly delete the entry on the other side as well
            otherEdge = @otherArchetype->EdgeDictionary[*compID]
            if otherEdge->AddReference = 0 ANDALSO _
                otherEdge->RemoveReference = 0 then
                
                otherArchetype->EdgeDictionary.DeleteKey(*compID)
            end if
            
            edge->AddReference = 0
            
        end if
        
        if edge->RemoveReference then
            otherArchetype = this.GetArchetypeByID(edge->RemoveReference)
            otherArchetype->SetAddMapping(*compID, 0)
            
            otherEdge = @otherArchetype->EdgeDictionary[*compID]
            if otherEdge->AddReference = 0 ANDALSO _
                otherEdge->RemoveReference = 0 then
                
                otherArchetype->EdgeDictionary.DeleteKey(*compID)
            end if
            
            edge->RemoveReference = 0
            
        end if

        if edge->AddReference = 0 ANDALSO edge->RemoveReference = 0 then
            'Delete our references 
            otherArchetype->EdgeDictionary.DeleteKey(*compID)
        end if

    DICTIONARY_FOREACH_NEXT
    
    'Remove this archetype from the relevant query lists
    if archetypeRef->EntityList.Count > 0 then
        this.RemoveArchetypeFromQueryPool(archetypeRef)
    end if
	
    'Remove the location specifiers
    FOR_IN(entID, EntityIDType, archetypeRef->EntityList)
        'Clear the location so this value isn't stumbled upon again
        location = @this.EntityToLocationDictionary[entID]
        location->Constructor()
        
        this.RemoveEntityID(entID)
        
    FOR_IN_NEXT
	
	'Run the destructors on our component lists, if necessary
	this.DestructArchetypeComponents(archetypeRef)
	
	'Also remove any pair components from the pair-using archetype list
    for i as integer = 0 to archetypeRef->ComponentIDList.Count - 1
        
        dim byref compDescriptor as ComponentDescriptorType = _
            this.ComponentDescriptorDictionary[archetypeRef->ComponentIDList[i]]
        
		if compDescriptor.IsPair then
			this.UnregisterArchetypeUsingPair(compDescriptor.ID, inArchetypeID)
		end if
        
    next
    
    'Remove the type from our mapping
    this.ComponentListToArchetypeIDDictionary.DeleteKey(archetypeRef->ComponentIDList)
    
    archetypeListRef = DYNAMIC_ARRAY_CAST(ArchetypeType ptr ptr, this.ArchetypeList, inArchetypeID)
    
    'We set the archetype pointer in our array to this tombstone value (-1)
    'This allows for easier identification between uninialized archetypes vs
    'deleted ones
    if *archetypeListRef = ARCHETYPE_TOMBSTONE then
        LogError("Hit archetype tombstone pointer?")
    end if
    delete(*archetypeListRef)
    
    'Set the archetype pointer to a value easy 
    'to crash on in case we hit this again
    *archetypeListRef = ARCHETYPE_TOMBSTONE
	
    this.DeletedArchetypeIDList.PushUDT(@inArchetypeID)
	
end sub

function ECSInstanceType.GetArchetypeByID( _
        inArchetypeID as ArchetypeIDType) as ArchetypeType ptr

    return *DYNAMIC_ARRAY_CAST(ArchetypeType ptr ptr, this.ArchetypeList, inArchetypeID)

end function

function ECSInstanceType.GetOrCreateArchetypeIDFromComponentList( _
		inComponentList as ComponentIDListType) as ArchetypeIDType
	
    dim archetypeID as ArchetypeIDType

    archetypeID = this.ComponentListToArchetypeIDDictionary[inComponentList]
    
    if archetypeID = 0 then
        'Archetype does not exist, create it
        archetypeID = this.AddArchetype(inComponentList)
    end if
	
	return archetypeID
	
end function

function ECSInstanceType.GetEntityActiveArchetype( _
        inEntityID as EntityIDType) as ArchetypeType ptr
    
    dim retArchetypePtr as ArchetypeType ptr ptr = 0
    dim location as EntityLocationSpecifierType ptr
    
    'Check the defer list first, use its archetype if found
    retArchetypePtr = this.CommandBuffer.DeferMoveEntityDictionary.KeyExistsGet(inEntityID)
    if retArchetypePtr then
        'Use the archetype we are deferring movement to
        return *retArchetypePtr
    end if
    
    'Check if entity exists second, use its archetype if found
    location = this.EntityToLocationDictionary.KeyExistsGet(inEntityID)
    if location then
        'Entity is in its correct archetype, use it
        return location->Archetype
    end if

    'Entity doesn't exist
    return 0
    
end function

sub ECSInstanceType.SortArchetypeIDQuery(_ 
        byref inArchetypeIDs as DynamicArrayType, _
        baseComponentID as ComponentIDType, _
        sortDirection as byte)
	
	if inArchetypeIDs.Count <= 1 then
		'0 and 1 length arrays have no business being sorted
		return
	end if
	
    dim componentSortIndexes as DynamicArrayType = _
        DynamicArrayType(sizeof(_QuerySortIndexPositionTupleType), inArchetypeIDs.Count)
    dim outArray as DynamicArrayType = _
        DynamicArrayType(sizeof(ArchetypeIDType), inArchetypeIDs.Count)
    dim tempTuple as _QuerySortIndexPositionTupleType
    
    dim tempArchIDArray as ArchetypeIDType ptr
    dim compDescriptor as ComponentDescriptorType ptr
    
    dim archetypeRef as ArchetypeType ptr
    dim pairCompID as PairComponentContainerType ptr
    
    'Construct a list of index + sort index tuples for each archetype ID
    DYNAMICARRAY_FOREACH_START(inArchetypeIDs, i, archID, ArchetypeIDType)
        
        archetypeRef = this.GetArchetypeByID(archID)
        
        tempTuple.SortIndex = 0
        
        pairCompID = archetypeRef->BaseToPairDictionary.KeyExistsGet(baseComponentID)
        if pairCompID then
            
            compDescriptor = this.ComponentDescriptorDictionary.KeyExistsGet(pairCompID->PairID)
            if compDescriptor then
            
                'Archetype has an applicable pair
                tempTuple.SortIndex = compDescriptor->SortIndex
            end if
        end if
        
        tempTuple.Position = i
        
        '_Log("position: ";tempTuple.Position;", index: ";tempTuple.SortIndex)
        
        componentSortIndexes.PushUDT(@tempTuple)
        
    DYNAMICARRAY_FOREACH_NEXT
    
    'Sort the tuples
    qsort( _
        @componentSortIndexes[0], _
        componentSortIndexes.Count, _
        sizeof(_QuerySortIndexPositionTupleType), _
        @_QuerySortIndexPositionTupleType.Compare)
    
    tempArchIDArray = inArchetypeIDs.GetArrayPointer()
    
    if sortDirection = 1 then
        'Recreate the archetype ID array based on the sorted tuple array
        DYNAMICARRAY_FOREACH_START(componentSortIndexes, i, tuple, _QuerySortIndexPositionTupleType)
            
            outArray.PushUDT(@tempArchIDArray[tuple.Position])
            
        DYNAMICARRAY_FOREACH_NEXT
    else
        
        DYNAMICARRAY_FOREACH_START_REVERSE(componentSortIndexes, i, tuple, _QuerySortIndexPositionTupleType)
            
            outArray.PushUDT(@tempArchIDArray[tuple.Position])
            
        DYNAMICARRAY_FOREACH_NEXT
        
    end if
    
    inArchetypeIDs = outArray

end sub

sub ECSInstanceType.SortQueryResultByComponent overload ( _
		byref inQuery as QueryType, _
		queryTerm as QueryTermType)
	
	if inQuery.PreparedFlag = 0 then
		LogError("Attempted to sort an unprepared query")
	end if
	
	if (queryTerm.Op AND (_SORTON_FORWARD OR _SORTON_BACKWARD)) = 0 then
		LogError("Unknown sort term: ";queryTerm.Op)
	end if
	
	dim direction as byte = iif(queryTerm.Op AND _SORTON_FORWARD, 1, -1)
	
	this.SortArchetypeIDQuery( _
		inQuery.ArchetypeIDs, _
		queryTerm.ComponentID, _
		direction)

end sub

sub ECSInstanceType.SortQueryResultByComponent overload ( _
	byref inQuickView as QuickViewType, _
	queryTerm as QueryTermType)

	if inQuickView.PreparedFlag = 0 then
		LogError("Attempted to sort an unprepared quick view")
	end if
	
	if (queryTerm.Op AND (_SORTON_FORWARD OR _SORTON_BACKWARD)) = 0 then
		LogError("Unknown sort term: ";queryTerm.Op)
	end if
	
	dim direction as byte = iif(queryTerm.Op AND _SORTON_FORWARD, 1, -1)
	
	this.SortArchetypeIDQuery( _
		inQuickView.ArchetypeIDs, _
		queryTerm.ComponentID, _
		direction)

end sub

'Sets up a query to be cached
sub ECSInstanceType.RegisterCachedQuery( _
		inQuery as QueryType ptr)

	if inQuery->UnsortedComponents.Count = 0 then
		'This query has no terms
		LogWarn("Cannot cache query with no terms: ";inQuery->Name)
		return
	end if
	
	inQuery->CachedInfo.IsCached = 1
	inQuery->CachedInfo.UseExistingData = 0
	
	FOR_IN(componentID, ComponentIDType, inQuery->UnsortedComponents)
		
		dim byref compDescriptor as ComponentDescriptorType = _
            this.ComponentDescriptorDictionary[componentID]
		
		dim queryList as DynamicArrayType ptr = this.ComponentToCachedQueryListDictionary[componentID]
		'Presumably the query pointer doesn't change
		'I hope that's an OK assumption
		queryList->PushUDT(@inQuery)
		
		if compDescriptor.IsPair then
			
			'Push the query into the base ID list too
			dim baseComponentID as ComponentIDType
            baseComponentID.ID = componentID.EntityID
			
			dim baseQueryList as DynamicArrayType ptr = this.ComponentToCachedQueryListDictionary[baseComponentID]
			baseQueryList->PushUDT(@inQuery)
		end if
		
	FOR_IN_NEXT

end sub

'Removes a query from the caching structures
sub ECSInstanceType.UnregisterCachedQuery( _
		inQuery as QueryType ptr)
	
	if inQuery->UnsortedComponents.Count = 0 then
		'This query has no terms
		LogWarn("Cannot unregister a cached query with no terms: ";inQuery->Name)
		return
	end if
	
	if inQuery->CachedInfo.IsCached = 0 then
		'Query is not cached
		LogWarn("Cannot unregister cached query that wasn't cached: ";inQuery->Name)
		return
	end if
	
	inQuery->CachedInfo.IsCached = 0
	inQuery->CachedInfo.UseExistingData = 0
	
	'Remove the query from each component-to-query list
	FOR_IN(componentID, ComponentIDType, inQuery->UnsortedComponents)
	
		dim byref compDescriptor as ComponentDescriptorType = _
            this.ComponentDescriptorDictionary[componentID]
			
		dim queryList as DynamicArrayType ptr = this.ComponentToCachedQueryListDictionary[componentID]
		
		'Linearly search for the query in each list
		'Hopefully this isn't done too often
		FOR_IN(query, QueryType ptr, *queryList)
			if query = inQuery then
				queryList->Remove(FOR_IN_ITER)
				FOR_IN_EXIT
			end if
		FOR_IN_NEXT
		
		if compDescriptor.IsPair then
			
			'Remove the query from the base component list too
			dim baseComponentID as ComponentIDType
            baseComponentID.ID = componentID.EntityID
			
			dim baseQueryList as DynamicArrayType ptr = this.ComponentToCachedQueryListDictionary[baseComponentID]

			FOR_IN(query, QueryType ptr, *baseQueryList)
				if query = inQuery then
					baseQueryList->Remove(FOR_IN_ITER)
					FOR_IN_EXIT
				end if
			FOR_IN_NEXT
		end if
		
	FOR_IN_NEXT
	
end sub

function ECSInstanceType.PrepareQuery( _
        byref inQuery as QueryType) as integer

    dim retVal as integer = 0

    dim tempArchetypeList as DynamicArrayType ptr

    dim componentDescriptor as ComponentDescriptorType ptr

    dim ANDArchetypeCount as uinteger = 0
    dim ANDArchetypeIDList as DynamicArrayType = DynamicArrayType(sizeof(ArchetypeIDType))
    
    dim NOTArchetypeCount as uinteger = 0
    dim NOTArchetypeIDList as DynamicArrayType = DynamicArrayType(sizeof(ArchetypeIDType))
    
    dim tempArchetypeArray as ArchetypeIDType ptr
    
    dim finalANDArray as DynamicArrayType = DynamicArrayType(sizeof(ArchetypeIDType))
    dim finalNOTArray as DynamicArrayType = DynamicArrayType(sizeof(ArchetypeIDType))

    dim sortonComponentID as ComponentIDType
    dim queryOnComponentCount as uinteger<32> = 0
    dim sortDirection as byte = 0
    
    dim currID as ArchetypeIDType
    dim count as integer
    
    'Confirm that this function was ran first, regardless of outcome
    inQuery.PreparedFlag = 1
	
    'Clear the metadata
    inQuery.MetaData = type<QueryType.MetaDataType>(0, 0, 0.0d)

    inQuery.MetaData.PrepareTime = Timer()
	
	if inQuery.CachedInfo.IsCached then
	
		if inQuery.CachedInfo.UseExistingData = 1 then
			'Query will use existing data
			this.RestartQuery(inQuery)
			goto setMetadata
		end if
		
		'Set cached data to valid
		'Any results after this point are valid
		inQuery.CachedInfo.UseExistingData = 1
	end if
    
    if inQuery.ComponentList.Count = 0 then
        'Empty query
        goto cleanup
    end if
    
    'Consider managing entity flushing elsewhere
    'this.FlushCommandBuffer()
    
    'Re-init our query variables
    'inQuery.NodeMap.Empty() 'Probably not necessary
    inQuery.ArchetypeIndex = 0
    inQuery.NodeCount = 0
    inQuery.ActiveArchetype = 0
 
    'Gather number of archetype IDs
    for i as integer = 0 to inQuery.UnsortedComponents.Count-1
        
        dim byref componentID as ComponentIDType = _
            *DYNAMIC_ARRAY_CAST(ComponentIDType ptr, inQuery.UnsortedComponents, i)

        dim byref flags as QueryOperatorEnum = _
            *DYNAMIC_ARRAY_CAST(QueryOperatorEnum ptr, inQuery.QueryOperators, i)
        
        dim op as QueryOperatorEnum
        dim sorton as QueryOperatorEnum
        
        if flags = 0 then
            'Default is _AND.
            'Allowing flags to be 0 keeps the system API cleaner
            flags = _AND
        end if
        
        op = flags AND (_AND OR _ANDNOT)
        sorton = flags AND (_SORTON_FORWARD OR _SORTON_BACKWARD)
        
        'We'll need the descriptor to differentiate between pair and normal components
        componentDescriptor = this.ComponentDescriptorDictionary.KeyExistsGet(componentID)
        if componentDescriptor = 0 then
            LogError( _
                !"Queried on non-existent component.\n"; _
                "Query name: ";inQuery.Name;!"\n"; _
                "Offending component: ";this.ComponentIDHumanReadable(componentID);!"\n"; _
                "Sorted component list: ";this.ComponentListHumanReadable(inQuery.ComponentList))
        end if
        
        if sorton then
            
            if componentDescriptor->IsBase = 0 then
                LogError( _
                    !"Query _SORTON clause may only be used on base components.\n"; _
                    "Query name: ";inQuery.Name;!"\n"; _
                    "Offending component: ";this.ComponentIDHumanReadable(componentID);!"\n"; _
                    "Sorted component list: ";this.ComponentListHumanReadable(inQuery.ComponentList))
            end if
            
            if sortonComponentID.ID <> 0 then
                LogError( _
                    !"Query cannot have more than one _SORTON clause.\n"; _
                    "Query name: ";inQuery.Name;!"\n"; _
                    "Sorted component list: ";this.ComponentListHumanReadable(inQuery.ComponentList))
            end if

            sortonComponentID = componentID
            
            sortDirection = iif(sorton AND _SORTON_FORWARD, 1, -1)

        end if
        
        'Get the archetypes associated with this component
        tempArchetypeList = this.ComponentToArchetypeIDListDictionary[componentID]

        if tempArchetypeList->Count = 0 ANDALSO op = _AND then
            'There are no entities that match this component.
            'Thus, no entities match this entire query
            goto cleanup
        end if
        
        select case as const op
            case _NULL
                'Do nothing
            case _AND
                ANDArchetypeCount += tempArchetypeList->Count
                queryOnComponentCount += 1
            case _ANDNOT
                NOTArchetypeCount += tempArchetypeList->Count
            case else
                LogError( _
                    !"Queried with invalid operator: ";op;!"\n"; _
                    "Query name: ";inQuery.Name;!"\n"; _
                    "Offending component: ";this.ComponentIDHumanReadable(componentID);!"\n"; _
                    "Sorted component list: ";this.ComponentListHumanReadable(inQuery.ComponentList))
                
        end select
        
    next
    
    if ANDArchetypeCount = 0 then
        LogError( _
            !"Query requires at least one AND clause.\n"; _
            "Query name: ";inQuery.Name;!"\n"; _
            "Sorted component list: ";inQuery.ComponentList.ToString())
    end if

    ANDArchetypeIDList.ResizeNoSave(ANDArchetypeCount)
    NOTArchetypeIDList.ResizeNoSave(NOTArchetypeCount)
    
    ANDArchetypeCount = 0
    NOTArchetypeCount = 0
    
    'Memcpy all archetypes into their respective lists based on operator
    for i as integer = 0 to inQuery.UnsortedComponents.Count-1
        dim srcPtr as ArchetypeIDType ptr
        dim dstPtr as ArchetypeIDType ptr
        
        dim byref componentID as ComponentIDType = _
            *DYNAMIC_ARRAY_CAST(ComponentIDType ptr, inQuery.UnsortedComponents, i)
        
        dim byref flags as QueryOperatorEnum = _
            *DYNAMIC_ARRAY_CAST(QueryOperatorEnum ptr, inQuery.QueryOperators, i)

        dim op as QueryOperatorEnum
        
        if flags = 0 then
            'Default is _AND.
            'Allowing flags to be 0 keeps the system API cleaner
            flags = _AND
        end if
        
        op = flags AND (_AND OR _ANDNOT)
        
        tempArchetypeList = this.ComponentToArchetypeIDListDictionary[componentID]
        
        srcPtr = tempArchetypeList->GetArrayPointer()
        
        'TODO: Figure out why adding "as const" here throws a warning in the C compiler
        select case op
            case _AND
                dstPtr = ANDArchetypeIDList.GetArrayPointer()
                dstPtr = @dstPtr[ANDArchetypeCount]
                ANDArchetypeCount += tempArchetypeList->Count
                
            case _ANDNOT
                dstPtr = NOTArchetypeIDList.GetArrayPointer()
                dstPtr = @dstPtr[NOTArchetypeCount]
                NOTArchetypeCount += tempArchetypeList->Count
            
            case else
                continue for
                
        end select

        memcpy(dstPtr, srcPtr, tempArchetypeList->Count * sizeof(ArchetypeIDType))
        
    next
    
    ANDArchetypeIDList.Count = ANDArchetypeCount
    NOTArchetypeIDList.Count = NOTArchetypeCount

    if inQuery.UnsortedComponents.Count = 1 then
        'No need to sort on a single component array
        inQuery.ArchetypeIDs = ANDArchetypeIDList
        retVal = 1
        goto cleanup
    end if
    
    inQuery.ArchetypeIDs.ResizeNoSave(ANDArchetypeIDList.Count)
    finalANDArray.ResizeNoSave(ANDArchetypeIDList.Count)
    finalNOTArray.ResizeNoSave(NOTArchetypeIDList.Count)
    
    'Sort the items
    'This is required because the archetype ID lists are not
    'always guaranteed to be sorted
    qsort( _
        @ANDArchetypeIDList[0], _
        ANDArchetypeIDList.Count, _
        sizeof(ArchetypeIDType), _
        @ArchetypeIDType_Compare)
    
    if NOTArchetypeIDList.Count > 0 then
        qsort( _
            @NOTArchetypeIDList[0], _
            NOTArchetypeIDList.Count, _
            sizeof(ArchetypeIDType), _
            @ArchetypeIDType_Compare)
    end if
    
    'Extract only duplicates that occur inComponentList.Count times
    
    tempArchetypeArray = ANDArchetypeIDList.GetArrayPointer()
    
    count = 0
    currID = cast(ArchetypeIDType, -1)
    
    for i as integer = 0 to ANDArchetypeIDList.Count-1
        
        if tempArchetypeArray[i] <> currID then
            count = 1
            currID = tempArchetypeArray[i]
        else
            count += 1
        end if
        
        if count = queryOnComponentCount then
            finalANDArray.PushUDT(@currID)
        end if

    next
    
    'We now have a list of archetypes that have all components
	
    'Remove any that contain the "ANDNOT" clause, if needed
    if NOTArchetypeIDList.Count > 0 then
        tempArchetypeArray = NOTArchetypeIDList.GetArrayPointer()
        
        count = 0
        currID = cast(ArchetypeIDType, -1)
        
        'Remove duplicates
        for i as integer = 0 to NOTArchetypeIDList.Count-1
    
            if tempArchetypeArray[i] <> currID then
                finalNOTArray.PushUDT(@tempArchetypeArray[i])
                currID = tempArchetypeArray[i]
            end if
            
        next
        
        dim saveIndex as integer = 0
        dim push as ubyte
        
        FOR_IN(x, ArchetypeIDType, finalANDArray)
        
            'TODO: optimize this.  The list is likely small, but
            'this is still an n^2 operation
            push = 1
            FOR_IN(y, ArchetypeIDType, finalNOTArray)
                if x = y then
                    push = 0
                    exit for
                end if
            FOR_IN_NEXT
            
            if push then
                inQuery.ArchetypeIDs.PushUDT(@x)
            end if
            
        FOR_IN_NEXT

    else
        inQuery.ArchetypeIDs = finalANDArray
    end if
    
    'Sort on the component sort index, if needed
    if sortonComponentID.ID <> 0 then
	
        this.SortArchetypeIDQuery(inQuery.ArchetypeIDs, sortonComponentID, sortDirection)
        
    end if
	
	setMetadata:
	
	retVal = iif(inQuery.ArchetypeIDs.Count > 0, 1, 0)
	
	'TODO: Evalutate if this metadata is worth the performance hit
    FOR_IN(archetypeID, ArchetypeIDType, inQuery.ArchetypeIDs)

        dim archetype as ArchetypeType ptr = this.GetArchetypeByID(archetypeID)
        inQuery.MetaData.EntityCount += archetype->EntityList.Count

    FOR_IN_NEXT
    
    inQuery.MetaData.ArchetypeCount = inQuery.ArchetypeIDs.Count
	
    cleanup:
    
    inQuery.MetaData.PrepareTime = Timer() - inQuery.MetaData.PrepareTime
	
	if inQuery.CachedInfo.IsCached ANDALSO retVal = 0 then
		'Cached queries could keep around
		'these bits and we don't want them to
		inQuery.ArchetypeIDs.ResizeNoSave(0)
	end if
	
    return retVal
    
end function

function ECSInstanceType.QueryNext( _
        byref inQuery as QueryType) as integer

    dim tempArchetype as ArchetypeType ptr
    dim componentIndex as ushort ptr
    
    dim archetypeList as ArchetypeIDType ptr
    
    if inQuery.PreparedFlag = 0 then
        LogError( _
            !"Query not prepared before iteration.\n"; _
            "Query name: ";inQuery.Name;", component list"; _
            this.ComponentListHumanReadable(inQuery.ComponentList))
    end if
    
    if inQuery.ComponentList.Count = 0 then
        'There's nothing to query on, what are you doing...
        LogWarn("Empty query. Query name:";inQuery.Name)
        goto cleanup
    end if
    
    'Convenience cast
    archetypeList = inQuery.ArchetypeIDs.GetArrayPointer()
    
    if inQuery.ActiveArchetype then
        inQuery.ActiveArchetype->LockedFlag -= 1
    end if
    
    while 1
        
        if inQuery.IsFinished() then
            'Iterated over all archetypes
            goto cleanup
        end if
        
        'Get a pointer to the next archetype in the list
        tempArchetype = this.GetArchetypeByID(archetypeList[inQuery.ArchetypeIndex])
        
        if tempArchetype->EntityList.Count = 0 then
            inQuery.ArchetypeIndex += 1
            LogWarn( _
                !"Unexpected empty archetype during query.\n"; _
                "Query name: ";inQuery.Name;", archetype: "; _
                this.ArchetypeHumanReadable(tempArchetype))
            continue while
        end if
        
        inQuery.ActiveArchetype = tempArchetype
        
        'Fill the mapping from componentID to data array
        for i as integer = 0 to inQuery.ComponentList.Count-1
            componentIndex = tempArchetype->ComponentIDDictionary.KeyExistsGet( _
                inQuery.ComponentList[i])
            if componentIndex = 0 then
                'This will arise when we're filtering on the base of a pair,
                'or using the _ANDNOT operator
                continue for
            end if
            inQuery.NodeMap[inQuery.ComponentList[i]] = tempArchetype->ComponentList[*componentIndex]
        next
        
        inQuery.ActiveEntities = tempArchetype->EntityList
        
        inQuery.NodeCount = tempArchetype->EntityList.Count
        inQuery.ArchetypeIndex += 1
        
        inQuery.ActiveArchetype->LockedFlag += 1
        
        return 1

    wend
    
    cleanup:
    
    inQuery.PreparedFlag = 0
    inQuery.ActiveArchetype = 0
    
    return 0

end function

function ECSInstanceType.PrepareQuery overload ( _
        byref inQuickView as QuickViewType) as integer

    dim retVal as integer = 0
    
    dim tempArchetypeList as DynamicArrayType ptr
    dim componentDescriptor as ComponentDescriptorType ptr

    'Confirm that this function was ran first, regardless of outcome
    inQuickView.PreparedFlag = 1

    inQuickView.MetaData = type<QueryType.MetaDataType>(0, 0, 0.0d)

    inQuickView.MetaData.PrepareTime = timer

    'Consider managing entity flushing elsewhere
    'this.FlushCommandBuffer()
    
    'Re-init our query variables
    inQuickView.ArchetypeIndex = 0
    inQuickView.NodeCount = 0
    inQuickView.ActiveArchetype = 0
    
    'Gather number of archetype IDs
    dim byref componentID as ComponentIDType = inQuickView.QueriedComponent

    'We'll need the descriptor to differentiate between pair and normal components
    componentDescriptor = this.ComponentDescriptorDictionary.KeyExistsGet(componentID)
    if componentDescriptor = 0 then
        LogError( _
            !"Created quick view on non-existent component.\n"; _
            "Offending component: ";this.ComponentIDHumanReadable(componentID);!"\n")
    end if

    'Get the archetypes associated with this component
    tempArchetypeList = this.ComponentToArchetypeIDListDictionary[componentID]
    
    if tempArchetypeList->Count = 0 then
        'There are no entities that match this component.
        'Thus, no entities match this entire query
        goto cleanup:
    end if
    
    inQuickView.ArchetypeIDs = *tempArchetypeList

    retVal = 1
        
    FOR_IN(archetypeID, ArchetypeIDType, inQuickView.ArchetypeIDs)

        dim archetype as ArchetypeType ptr = this.GetArchetypeByID(archetypeID)
        inQuickView.MetaData.EntityCount += archetype->EntityList.Count

    FOR_IN_NEXT

    inQuickView.MetaData.ArchetypeCount = inQuickView.ArchetypeIDs.Count

    cleanup:

    inQuickView.MetaData.PrepareTime = timer - inQuickView.MetaData.PrepareTime

    return retVal

end function

function ECSInstanceType.QueryNext overload ( _
        byref inQuickView as QuickViewType) as integer

    dim tempArchetype as ArchetypeType ptr
    dim componentIndex as ushort
    
    dim archetypeList as ArchetypeIDType ptr
    
    if inQuickView.PreparedFlag = 0 then
        LogError( _
            !"Quick view not prepared before iteration.\n"; _
            "Quick view component"; _
            this.ComponentIDHumanReadable(inQuickView.QueriedComponent))
    end if

    'Convenience cast
    archetypeList = inQuickView.ArchetypeIDs.GetArrayPointer()
    
    if inQuickView.ActiveArchetype then
        inQuickView.ActiveArchetype->LockedFlag -= 1
    end if
    
    while 1
        
        if inQuickView.ArchetypeIndex >= inQuickView.ArchetypeIDs.Count then
            'Iterated over all archetypes
            goto cleanup
        end if
        
        'Get a pointer to the next archetype in the list
        tempArchetype = this.GetArchetypeByID(archetypeList[inQuickView.ArchetypeIndex])
        
        if tempArchetype->EntityList.Count = 0 then
            inQuickView.ArchetypeIndex += 1
            LogWarn( _
                !"Unexpected empty archetype during quick view iteration.\n"; _
                "Quick view component"; _
                this.ComponentIDHumanReadable(inQuickView.QueriedComponent);!"\n"_
                "Archetype: ";this.ArchetypeHumanReadable(tempArchetype))
            continue while
        end if
        
        inQuickView.ActiveArchetype = tempArchetype
        
        inQuickView.ActiveEntities = tempArchetype->EntityList
        
        inQuickView.NodeCount = tempArchetype->EntityList.Count
        inQuickView.ArchetypeIndex += 1
        
        inQuickView.ActiveArchetype->LockedFlag += 1
        
        return 1

    wend
    
    cleanup:
    
    inQuickView.PreparedFlag = 0
    inQuickView.ActiveArchetype = 0
    
    return 0

end function

sub ECSInstanceType.RestartQuery overload ( _
        byref inQuery as QueryType)

    if inQuery.ActiveArchetype then
        inQuery.ActiveArchetype->LockedFlag -= 1
    end if

    inQuery.ActiveArchetype = 0
    inQuery.ArchetypeIndex = 0
    inQuery.NodeMap.Empty()

    'This is an honor system thing
    'Don't restart a query that hasn't been prepared
    inQuery.PreparedFlag = 1
    
end sub

sub ECSInstanceType.RestartQuery overload ( _
        byref inQuickView as QuickViewType)

    if inQuickView.ActiveArchetype then
        inQuickView.ActiveArchetype->LockedFlag -= 1
    end if

    inQuickView.ActiveArchetype = 0
    inQuickView.ArchetypeIndex = 0

    inQuickView.PreparedFlag = 1

end sub

function ECSInstanceType.GetPhase( _
		inPhase as PhaseEnum) as DynamicArrayType ptr
	
	select case as const inPhase
		case this.PREPARE_PHASE, _
			this.LOAD_PHASE, _
			this.UPDATE_PHASE, _
			this.DELETE_PHASE, _
			this.SAVE_PHASE
			
			return *DYNAMIC_ARRAY_CAST(DynamicArrayType ptr ptr, this.PhaseList, inPhase)
			
		case else
			return cast(DynamicArrayType ptr, 0)
			
	end select

end function

sub ECSInstanceType.AddSystem( _
		byref inSystem as SystemType ptr, _
		inPhase as PhaseEnum)
	
	if inSystem = 0 then
		LogError("Passed in null system")
	end if
	
	if inSystem->Query.CheckValidity() = 0 then
        'Do something?...
    end if
	
	dim index as uinteger
	dim callbackType as PipelineMapType ptr
	dim phase as DynamicArrayType ptr
	
	if this.SystemNameToIndexDictionary.KeyExists(inSystem->Name) then
		LogWarn("System name already exists: ";inSystem->Name)
	elseif this.EventQueueNameToIndexDictionary.KeyExists(inSystem->Name) then
		LogWarn("System name collides with event queue name: ";inSystem->Name)
	else
		this.SystemNameToIndexDictionary[inSystem->Name] = this.SystemList.Count - 1
	end if
	
	phase = this.GetPhase(inPhase)
	if phase = 0 then
		LogError("Invalid phase passed in: ";inPhase)
	end if
	
	'TODO: remove
	/'index = this.PipelineList.Reserve()
	callbackType = DYNAMIC_ARRAY_CAST(PipelineMapType ptr, this.PipelineList, index)
	
	callbackType->SystemType = callbackType->SYSTEM_CALLBACK
	callbackType->Index = this.SystemList.PushUDT(@inSystem)
	callbackType->Name = inSystem->Name
	'/
	index = phase->Reserve()
	callbackType = DYNAMIC_ARRAY_CAST(PipelineMapType ptr, *phase, index)
	
	callbackType->SystemType = callbackType->SYSTEM_CALLBACK
	callbackType->Phase = inPhase
	callbackType->Index = this.SystemList.PushUDT(@inSystem)
	callbackType->Name = inSystem->Name
	
	'Push this system into our module's namespace
	dim byref module as ECSInstanceType.ModuleInfoType = _
		*cast(ECSInstanceType.ModuleInfoType ptr, @this.Modules[this.ModuleNamespaceIndex])
	index = module.SystemsList.Reserve(1)
	
	'Copy the string name in with namespace if needed
	dim byref _name as string = *cast(string ptr, @module.SystemsList[index])
	_name = inSystem->Name
	
end sub

sub ECSInstanceType.AddTickSystem( _
        byref inSystem as SystemType ptr, _
		inPhase as PhaseEnum = UPDATE_PHASE)
    
    LogStat("Added tick system: ";inSystem->Name)
    
	inSystem->RateCappedFlag = 1
	
	this.AddSystem(inSystem, inPhase)
	
end sub

sub ECSInstanceType.AddUnboundedSystem( _
        byref inSystem as SystemType ptr, _
		inPhase as PhaseEnum = UPDATE_PHASE)
    
    LogStat("Added unbounded system: ";inSystem->Name)
    
	inSystem->RateCappedFlag = 0
	
	this.AddSystem(inSystem, inPhase)
	
end sub

sub ECSInstanceType.AddEventHandlerSystem( _
		inEventHandlerName as string, _
		inEventID as EventIDType, _
		inCallback as sub(FBECS_EVENT_CALLBACK_SIGNATURE), _
		inPhase as PhaseEnum = UPDATE_PHASE)
	
	dim reservedQueue as ECSEventQueueType ptr
	dim index as uinteger
	dim callbackType as PipelineMapType ptr
	dim phase as DynamicArrayType ptr
	
	if inEventID <= 0 ORELSE _
		inEventID >= this.EventQueueList.Count then

		LogError("Unknown event ID: ";inEventID)
	
	end if
	
	'The queue is instantiated when the event is registered
	reservedQueue = cast(ECSEventQueueType ptr, @this.EventQueueList[inEventID])
	
	reservedQueue->Locked = 0
	
	if this.EventQueueNameToIndexDictionary.KeyExists(inEventHandlerName) then
		LogWarn("Event handler name already exists: ";inEventHandlerName)
	elseif this.SystemNameToIndexDictionary.KeyExists(inEventHandlerName) then
		LogWarn("Event name collides with system name: ";inEventHandlerName)
	else
		this.EventQueueNameToIndexDictionary[inEventHandlerName] = reservedQueue->ID
	end if
	
	phase = this.GetPhase(inPhase)
	if phase = 0 then
		LogError("Invalid phase passed in: ";inPhase)
	end if

	index = phase->Reserve()
	callbackType = DYNAMIC_ARRAY_CAST(PipelineMapType ptr, *phase, index)
	
	callbackType->SystemType = callbackType->EVENT_CALLBACK
	callbackType->Phase = inPhase
	callbackType->Index = this.EventCallbackList.PushUDT(@inCallback)
	callbackType->EventID = reservedQueue->ID
	callbackType->Name = inEventHandlerName
	
	'Push this event handler into our module's namespace
	dim byref module as ECSInstanceType.ModuleInfoType = _
		*cast(ECSInstanceType.ModuleInfoType ptr, @this.Modules[this.ModuleNamespaceIndex])
	index = module.SystemsList.Reserve(1)
	
	'Copy the string name in with namespace if needed
	dim byref _name as string = *cast(string ptr, @module.SystemsList[index])
	_name = inEventHandlerName
	
	LogStat("Added event handler system: ";inEventHandlerName; _
		" Index: ";callbackType->Index; _
		" EventID; ";callbackType->EventID; _
		" Callback: ";inCallback)
	
end sub

sub ECSInstanceType.RunSystem( _
        byref inSystem as SystemType, _
        delta as double = 0.0d)
	
    if this.PrepareQuery(inSystem.Query) = 0 then
        'Do not run systems when they don't match anything
        return
    end if
    
    this.DeferMode = 1
	
	'_Log("Running system: ";inSystem.Name)
    inSystem.Callback(this, inSystem.Query, delta)
	'_Log("Done running system: ";inSystem.Name)
	
	if inSystem.Query.IsFinished() = 0 then
		'System returned without fully iterating the query
		'This might be an optional LogWarn situation
	    inSystem.Query.Terminate()
	end if

    this.DeferMode = 0
    
    this.FlushCommandBuffer()
    
end sub

sub ECSInstanceType.RunEventHandler( _
		byref inEventQueue as ECSEventQueueType, _
		inCallback as sub(FBECS_EVENT_CALLBACK_SIGNATURE), _
		delta as double = 0.0d)

	if inEventQueue.Events.Count = 0 then
		'No events, don't run
		return
	end if
	
	this.DeferMode = 1
	inEventQueue.Locked = 1
	inCallback(this, inEventQueue.Events, delta)
	
	inEventQueue.Locked = 0
	this.DeferMode = 0
	
	this.FlushCommandBuffer()
	inEventQueue.Empty()
	inEventQueue.MergeDeferredEvents()

end sub

sub ECSInstanceType.SetSystemRefreshRate( _
        inRefreshRate as uinteger)
    
    this.SystemRefreshRate = 1.0d / cast(double, inRefreshRate)
    this.InternalTimer = timer
    
end sub

sub ECSInstanceType.SetSystemEnabled( _
		byref inSystem as SystemType, _
		inEnabledFlag as ubyte)

	inSystem.Enabled = iif(inEnabledFlag <> 0, 1, 0)
	
end sub

sub ECSInstanceType.ImportModule( _
		inModuleCallback as sub(IMPORT_MODULE_PARAMETERS), _
		inModuleName as zstring ptr)
	
	dim index as uinteger = this.Modules.Reserve(1)
	dim module as ECSInstanceType.ModuleInfoType ptr = cast(ECSInstanceType.ModuleInfoType ptr, @this.Modules[index])

	'Default construct a module info type ptr
	dim tmp as ECSInstanceType.ModuleInfoType
	'Swap the contents with our array's space
	swap tmp, *module
	
	module->Name = *inModuleName
	
	'Set the namespace to this module's index
	this.ModuleNamespaceIndex = index
	
	'Import the module
	inModuleCallback(this)
	
	'Re-set the namespace back to global
	this.ModuleNamespaceIndex = 0
	
	this.FlushCommandBuffer()
	
end sub

sub ECSInstanceType.Update()
    
    dim timerCopy as double = timer
    dim delta as double = timerCopy - this.InternalTimer

    dim doTickUpdate as ubyte = 0

    timerCopy = this.InternalTimer

    if delta >= this.SystemRefreshRate then
        
        'Delta time has been surpassed
        doTickUpdate = 1
        
        while this.InternalTimer + this.SystemRefreshRate <= timerCopy + delta
            this.InternalTimer += this.SystemRefreshRate
        wend
        
    end if
	
	FOR_IN(phase, DynamicArrayType ptr, this.PhaseList)
		FOR_IN(pipeline, PipelineMapType, *phase)
			
			select case as const pipeline.SystemType
			
				case pipeline.EVENT_CALLBACK
					dim eventQueue as ECSEventQueueType ptr = this.GetEventQueue(pipeline.EventID)
					
					dim callback as sub(FBECS_EVENT_CALLBACK_SIGNATURE) ptr = _
						cast(any ptr, @this.EventCallbackList[pipeline.Index])
					
					'TODO: Check if we ever enqueue events which don't have a handler
					'Maybe I could check callback for 0 or pipeline.Index for 0
					'which would indicate no callback for a registered event?
					
					/'if eventQueue->Events.Count <> 0 then
						_Log("Running event handler: ";pipeline.Name)
					end if
					'/
					this.RunEventHandler(*eventQueue, *callback, delta)
					
					/'if eventQueue->Events.Count <> 0 then
						_Log("Done running event handler: ";pipeline.Name)
					end if
					'/
				case pipeline.SYSTEM_CALLBACK
					dim sys as SystemType ptr = _
						*cast(SystemType ptr ptr, @this.SystemList[pipeline.Index])
					
					if (sys->RateCappedFlag ANDALSO doTickUpdate = 0) ORELSE _
						(sys->Enabled = 0) then
						'Not ready to update ticked systems or system is disabled
						FOR_IN_CONTINUE
					end if

					this.RunSystem(*sys, this.SystemRefreshRate)
					
				case else
					LogError("Unknown callback type hit: ";pipeline.SystemType)
					
			end select
			
		FOR_IN_NEXT
	FOR_IN_NEXT

    'Flush all pending changes to save potentially massive updates
    'if a bunch of moves get queued up over multiple updates and
    'then suddenly get consumed
    this.FlushCommandBuffer()
	
end sub

function ECSInstanceType.ComponentIDHumanReadable( _
        componentID as ComponentIDType) as string
    
    dim retString as string = ""
    dim compDescriptor as ComponentDescriptorType ptr
    
    compDescriptor = this.ComponentDescriptorDictionary.KeyExistsGet(componentID)
    if compDescriptor = 0 then
            
        retString = retString & componentID.ToString()
    else
        
        if compDescriptor->Name = "" then
            retString = retString & componentID.ToString()
        else
            retString = retString & compDescriptor->Name
        end if
        
    end if

    return retString
    
end function

function ECSInstanceType.ComponentListHumanReadable( _
        byref inComponentList as ComponentIDListType) as string
    
    dim retString as string = ""
    
    dim compDescriptor as ComponentDescriptorType
    
    retString = retString & "{"
    
    for i as integer = 0 to inComponentList.Count-1
        
        retString = retString & this.ComponentIDHumanReadable(inComponentList[i])

        if i < inComponentList.Count-1 then
            retString = retString & ", "
        end if
    
    next

    retString = retString & "}"
    
    return retString
    
end function

sub ECSInstanceType.ListEntityComponents( _
        byref inEntityID as EntityIDType)

	dim location as EntityLocationSpecifierType ptr

	LogStat("Entity: ";inEntityID.ToString();)

	location = this.EntityToLocationDictionary.KeyExistsGet(inEntityID)
	if location = 0 then
		_Log(" was not found.")
		return
	end if
	
	if location->Archetype = 0 then		
		_Log(" is not in any archetype?")
		return
	end if
	
	_Log( _
		" is in archetype: "; _
		location->Archetype->ID;" with components: "; _
		this.ComponentListHumanReadable(location->Archetype->ComponentIDList))

end sub

function ECSInstanceType.ArchetypeHumanReadable( _
        inArchetype as ArchetypeType ptr) as string

    dim retString as string = ""
    
    retString = retString & "{"
    retString = retString & "id: " & inArchetype->ID & ", "
	retString = retString & "entity count: " & inArchetype->EntityList.Count & ", "
    retString = retString & this.ComponentListHumanReadable( _
        inArchetype->ComponentIDList)
    retString = retString & "}"
    
    return retString

end function

sub ECSInstanceType.LogFragmentationStats()
    
    dim emptyCount as integer = 0
    dim archetypeCount as integer = 0
    dim archetypeList as DynamicArrayType = DynamicArrayType(sizeof(ArchetypeType ptr))
    
    this.FlushCommandBuffer()
    
    DYNAMICARRAY_FOREACH_START(this.ArchetypeList, i, arch, ArchetypeType ptr)
        
        if arch->ComponentList <> 0 ANDALSO arch->ComponentList[0]->Count then
            archetypeList.PushUDT(@arch)
            archetypeCount += 1
        else
            emptyCount += 1
        end if
        
    DYNAMICARRAY_FOREACH_NEXT
    
    LogStat("ARCHETYPE FRAGMENTATION STATS")
    LogStat("Empty Archetype count: ";emptyCount)
    LogStat("Used Archetype count : ";archetypeCount)
    LogStat(!"Archetype ID: Entity Count: Component List")
    
    FOR_IN(arch, ArchetypeType ptr, archetypeList)
        LogStat( _
            "";arch->ID;!": \t";arch->ComponentList[0]->Count;!": \t"; _
            this.ComponentListHumanReadable(arch->ComponentIDList))
        _Log("Entities: ";)
        FOR_IN(entID, EntityIDType, arch->EntityList)
            _Log(entID.ToString();", ";)
        FOR_IN_NEXT
        _Log("")
    FOR_IN_NEXT
    
end sub

sub ECSInstanceType.LogPipeline()
	
	LogStat("Pipeline:")

	dim i as integer = 0
	FOR_IN(phase, DynamicArrayType ptr, this.PhaseList)
		LogStat("---Phase: ";FOR_IN_ITER)
		FOR_IN(pipeline, PipelineMapType, *phase)
			
			select case as const pipeline.SystemType
			
				case pipeline.EVENT_CALLBACK
					LogStat(" >";i;": ";pipeline.Name)
					
				case pipeline.SYSTEM_CALLBACK
					LogStat(" |";i;": ";pipeline.Name)
					
				case else
					LogError("Unknown callback type hit: ";pipeline.SystemType)
					
			end select
			
			i += 1
			
		FOR_IN_NEXT
		LogStat("")
	FOR_IN_NEXT

end sub

sub ECSInstanceType.LogModules()
	
	dim moduleName as string
	
	LogStat("Imported Modules:")
	
	FOR_IN(module, ECSInstanceType.ModuleInfoType, this.Modules)
		if module.Name = "" then
			moduleName = "GLOBAL"
		else
			moduleName = module.Name
		end if
		LogStat("---";moduleName)
		LogStat("    Systems:")
		FOR_IN(_name, string, module.SystemsList)
			LogStat("        ";_name)
		FOR_IN_NEXT
		LogStat("    Components:")
		FOR_IN(_name, string, module.ComponentsList)
			LogStat("        ";_name)
		FOR_IN_NEXT
		LogStat("    Events:")
		FOR_IN(_name, string, module.EventsList)
			LogStat("        ";_name)
		FOR_IN_NEXT
		LogStat("")
	FOR_IN_NEXT
	
end sub

#undef ARCHETYPE_TOMBSTONE

end namespace

#endif
