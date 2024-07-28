#ifndef ECSInstance_bi
#define ECSInstance_bi

#include once "../utilities/Dictionary.bi"
#include once "../utilities/DynamicArray.bi"

#include once "Entity.bi"
#include once "Component.bi"
#include once "Archetype.bi"
#include once "QueryIterator.bi"
#include once "QuickView.bi"
#include once "System.bi"
#include once "ECSEvents.bi"
#include once "CommandBuffer.bi"

namespace FBECS

DEFINE_DICTIONARY_TYPE(EntityIDType, FBECS.EntityLocationSpecifierType, DictionaryType_EntIDEntSpecifier)
DEFINE_DICTIONARY_TYPE(ComponentIDType, ComponentDescriptorType, DictionaryType_CompIDCompDesc)
DEFINE_DICTIONARY_TYPE(ComponentIDType, DynamicArrayType ptr, DictionaryType_CompIDDynamicArray)
DEFINE_DICTIONARY_TYPE(ComponentIDListType, ArchetypeIDType, DictionaryType_CompIDListArchID)
DEFINE_DICTIONARY_TYPE(EntityIDType, ArchetypeType ptr, DictionaryType_EntIDArchPtr)

'Holds the parameters for the sub that imports a module
#define IMPORT_MODULE_PARAMETERS _ \
	byref inECS as FBECS.ECSInstanceType

type ECSInstanceType

    'Manager class for an ECS instance

    'ENTITY FRONT
    
    'Entity to archetype dictionary
    dim as DictionaryType_EntIDEntSpecifier EntityToLocationDictionary
    
    'List of entity IDs to reuse
    dim as DynamicArrayType DeletedEntityIDList = DynamicArrayType(sizeof(EntityIDType))

    'Highest unused entity ID
    dim as uinteger<32> HighestEntityID
    
    'Builtin childof component used to create hierarchies
    dim as ComponentIDType ChildOfTag
    
    'COMPONENT FRONT
	
    'Map of component IDs to component descriptor
    dim as DictionaryType_CompIDCompDesc ComponentDescriptorDictionary
    
    'Map of component ID to archetype list
    dim as DictionaryType_CompIDDynamicArray ComponentToArchetypeIDListDictionary
	
	'Map of component ID to list of cached queries
	dim as DictionaryType_CompIDDynamicArray ComponentToCachedQueryListDictionary
    
	'Special mapping of pair component ID to archetype IDs
	'Since the component ID to arch ID list only maps queryable archetypes,
	'we need a separate mapping for all archetypes using a particular pair ID
	dim as DictionaryType_CompIDDynamicArray PairToArchetypeIDListDictionary
	
    'Map of component ID list to archetype ID
    dim as DictionaryType_CompIDListArchID ComponentListToArchetypeIDDictionary
	
	'EVENT FRONT
	
	'List of registered event queues
	'Reserve the slot in the constructor to ensure we can use 0 as a null event ID
	dim as DynamicArrayType EventQueueList = DynamicArrayType(sizeof(ECSEventQueueType), 1)
	
	'List of event callbacks.  One event may correspond to multiple callbacks
	dim as DynamicArrayType EventCallbackList = DynamicArrayType(sizeof(sub(FBECS_EVENT_CALLBACK_SIGNATURE)), 1)
	
	'Dictionary of event queue names to index
	dim as DictionaryType_StrInt EventQueueNameToIndexDictionary
	
    'ARCHETYPE FRONT
    
    'List of archetypes
    dim as DynamicArrayType ArchetypeList = DynamicArrayType(sizeof(ArchetypeType ptr))
    
	'List of deleted archetype IDs to recycle
    dim as DynamicArrayType DeletedArchetypeIDList = DynamicArrayType(sizeof(ArchetypeIDType))
    
    'SYSTEM FRONT
    
    'List of references to externally created systems to run on update.
	'Systems are run in order they were added.
    dim as DynamicArrayType SystemList = DynamicArrayType(sizeof(SystemType ptr))
	
	'Dictionary of system names to its index
	dim as DictionaryType_StrInt SystemNameToIndexDictionary
	
	'The refresh rate for the system to run tick systems on
    dim as double SystemRefreshRate
	
	'Holds the last timer value
    dim as double InternalTimer
    
	'CALLBACK FRONT
	
	'Enumerator holding the default phases
	'Changes to this list should also modify the GetPhase() function
	enum PhaseEnum
		PREPARE_PHASE = 0 'Prepare/construct your data/systems
		LOAD_PHASE        'Load resources
		UPDATE_PHASE      'Update data
		SAVE_PHASE        'Save out resources
		DELETE_PHASE      'Delete or clean up resources
		PHASE_END_MARKER 'Marks the end of enum, do not use
	end enum
	
	'[Internal] Container mapping system type to a phase & index
	type PipelineMapType
		
		enum PIPELINE_TYPE
			EVENT_CALLBACK = 0
			SYSTEM_CALLBACK = 1
		end enum

		dim as ubyte SystemType
		dim as PhaseEnum Phase
		dim as uinteger<32> Index
		dim as EventIDType EventID
		dim as string Name
		
	end type
	
	'List composing the event callbacks and system callbacks
	dim as DynamicArrayType PipelineList = DynamicArrayType(sizeof(PipelineMapType))
	
	'List of system pipelines to run sequentially.  Holds an array of pipeline lists
	dim as DynamicArrayType PhaseList = DynamicArrayType(sizeof(DynamicArrayType ptr), PHASE_END_MARKER)
	
	'MODULE FRONT
	
	'[Internal] Container of info about a module
	type ModuleInfoType
		dim as string Name
		'List of systems and event handlers imported by this module
		dim as DynamicArrayType SystemsList = DynamicArrayType(sizeof(string))
		'List of components
		dim as DynamicArrayType ComponentsList = DynamicArrayType(sizeof(string))
		'List of events
		dim as DynamicArrayType EventsList = DynamicArrayType(sizeof(string))

		declare destructor()
	end type
	
	'An index that represents which module is currently indexed
	'0 is the global ECS namespace
	dim as uinteger<32> ModuleNamespaceIndex
	
	'List of modules that have been imported, in order of import
	dim as DynamicArrayType Modules = DynamicArrayType(sizeof(ModuleInfoType))
	
    'INTERNAL OPTIMIZATION FRONT

    'Command buffer which will hold deferred changes to the ECS
	'Note that events hold their own deferred values
    dim as ECSCommandBufferType CommandBuffer
    
    'Flag to decide whether commands are deferred or not
    dim as ubyte DeferMode
    
    'API FRONT
    
    declare constructor()
    declare destructor()
    
    'Returns a new unique EntityIDType
    declare function CreateNewEntity overload () as EntityIDType
    
    'Returns a new unique EntityIDType with component declaration
    declare function CreateNewEntity overload ( _
        byref inComponentList as ComponentIDListType) as EntityIDType
    
    'Returns a new unique EntityIDType *without a generation*
    declare function CreateNewComponent() as EntityIDType
    
    '[Internal] Create an entity given a specific ID
    declare sub CreateEntityFromID( _
        inEntityID as EntityIDType, _
		inArchetypeID as ArchetypeIDType)
    
    '[Internal] Get the next available entity ID that's never been used
    declare function GetNextUnusedEntityID() as EntityIDType
    
    '[Internal] Get the next available entity ID
    'Whether that's a brand new one, or a recycled one
    declare function GetNextEntityID() as EntityIDType
    
    'Returns whether or not a given entity ID points to an existing entity
    declare function EntityExists( _
        inEntityID as EntityIDType) as integer
    
    'Combines the base and target into one component ID
    declare function GeneratePairComponent( _
        inBaseID as ComponentIDType, _
        inTargetID as ComponentIDType) as ComponentIDType
    
    'Adds a component to the pool of declared components
    declare function RegisterComponent( _
        inComponentTypeSize as uinteger<32>, _
        inComponentName as zstring ptr, _
        inComponentCtor as sub(as any ptr) = 0, _
        inComponentDtor as sub(as any ptr) = 0, _
        inComponentCopy as sub(as any ptr, as any ptr) = 0, _
        inComponentMove as sub(as any ptr, as any ptr) = 0) as ComponentIDType
    
    'Create a component and add its own data to itself
    'For instance, you could create a gravityComponent to 
    'have a single component that holds the value of 
    'gravity like a global constant variable (e.g. -9.81)
    declare function RegisterSingletonComponent( _
        inComponentTypeSize as uinteger<32>, _
        inComponentName as zstring ptr, _
        inComponentData as any ptr = 0, _
        inComponentCtor as sub(as any ptr) = 0, _
        inComponentDtor as sub(as any ptr) = 0, _
        inComponentCopy as sub(as any ptr, as any ptr) = 0, _
        inComponentMove as sub(as any ptr, as any ptr) = 0) as ComponentIDType
    
    'Create a component that combines two different entities
    'TODO: change argument types to EntityIDType
    declare function RegisterPairComponent( _
        inBaseComponentID as ComponentIDType, _
        inTargetID as ComponentIDType, _
		inComponentTypeSize as uinteger<32> = 0, _
        inComponentCtor as sub(as any ptr) = 0, _
        inComponentDtor as sub(as any ptr) = 0, _
        inComponentCopy as sub(as any ptr, as any ptr) = 0, _
        inComponentMove as sub(as any ptr, as any ptr) = 0) as ComponentIDType
    
	'Delete a pair component
	'These are the only components that can be created at run-time
	'so they're the only ones that can be deleted at run-time
	declare sub DeletePairComponent( _
		inPairID as ComponentIDType)
	
	'Register an event type
	declare function RegisterEvent( _
		inEventTypeSize as uinteger<32>, _
		inEventName as zstring ptr, _
		inEventDtor as sub(as any ptr) = 0) as EventIDType
	
	'[Internal] Returns an event queue given an event ID
	'Does not check bounds
	declare function GetEventQueue( _
		inEventID as EventIDType) as ECSEventQueueType ptr
	
	'Preallocate enough space to hold at least inEventCount more events
	'To be used when a large number of events will be queued and the 
	'event count is roughly known
	declare sub PreAllocateEvents( _
		inEventID as EventIDType, _
		inEventCount as uinteger)
	
	'Enqueue an event
	declare sub EnqueueEvent( _
		inEventID as EventIDType, _
		inEventData as any ptr = 0)
	
	'Empties the queue of a given event
	'This should not be called by a handler of that same event
	declare sub EmptyEventQueue( _
		inEventID as EventIDType)
	
    'Attaches a component to an entity
    'Optionally, you can specify the component data
    declare sub AddComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType, _
        inComponentSize as integer = 0, _
        inComponentData as any ptr = 0)
    
    'Removes a component from an entity
    declare sub RemoveComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType)
    
    'Checks if entity has a component
    'Returns 0 if false, -1 if true
    declare function HasComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType) as integer
    
    'Gets a pointer to the data of a component for a given entity
    declare function GetComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType) as any ptr
    
    'Gets the value of a singleton component
    '(A singleton where a component is added to itself)
    declare function GetSingletonComponent( _
        inComponentID as ComponentIDType) as any ptr
    
    'Returns the base component ID of a pair component
    declare function GetPairTarget( _
        inComponentID as ComponentIDType) as EntityIDType
    
    'Declares an entity a child of another entity
    declare sub AddChildOf( _
        inChildID as EntityIDType, _
        inParentID as EntityIDType)
    
    'Returns whether or not an entity has children
    declare function HasChildren( _
        inEntityID as EntityIDType) as integer
    
    'Returns whether or not an entity has a parent
    declare function HasParent( _
        inEntityID as EntityIDType) as integer
    
	'Returns whether or not an entity is an ancestor
	'of another entity (e.g. parent of a parent)
	'Args can be swapped to get a complementary "IsDescendentOf"
	declare function IsAncestorOf( _
		inAncestorID as EntityIDType, _
		inDescendentID as EntityIDType) as integer

    'Returns the pair container for the (ChildOfTag, parentID) pair, if any
    declare function GetParentPairContainer( _
        inEntityID as EntityIDType) as PairComponentContainerType
    
    'Returns the parent of an entity, or a 0 entity if not
    declare function GetParent( _
        inEntityID as EntityIDType) as EntityIDType
    
	'Swap a child's parent for another
	declare sub ChangeParent( _
		inChildID as EntityIDType, _
		inNewParentID as EntityIDType)
	
    'Attaches a signed integer to a component.  This signed integer may be sorted on
    'when querying, ensuring that certain archetypes are visited before others.
    'This can be useful when creating parent/child hierarchies etc.
    declare sub AssignComponentSortIndex( _
        inComponentID as ComponentIDType, _
        inSortIndex as integer<32>)
    
    'Returns the sort index
    declare function GetComponentSortIndex( _
        inComponentID as ComponentIDType) as integer<32>
    
    '[Internal] Copy component data
    'If user provides a copy function, that is used
    'Otherwise, this is just a memcpy call
    declare sub CopyComponentData( _
        toPointer as any ptr, _
        fromPointer as any ptr, _
        inComponentID as ComponentIDType)
    
    '[Internal] Move component data (transfer ownership)
    'If user provides a move function, that is used
    'Otherwise, this is just a memcpy call
    declare sub MoveComponentData( _
        toPointer as any ptr, _
        fromPointer as any ptr, _
        inComponentID as ComponentIDType)
    
    '[Internal] Add an archetype to the component query pool.
    'This gets called when an archetype gets its first entity
    declare sub AddArchetypeToComponentQueryPool( _
        archetypeRef as ArchetypeType ptr, _
        componentID as ComponentIDType)
    
    '[Internal] Remove an archetype from the component query pool.
    'This gets called when an archetype removes its last entity
    declare sub RemoveArchetypeFromComponentQueryPool( _
        archetypeRef as ArchetypeType ptr, _
        componentID as ComponentIDType) 
    
    '[Internal] Remove an archetype from all of its component query pools.
    'This gets called when an archetype is deleted or an archetype
    'removes its last entities.
    declare sub RemoveArchetypeFromQueryPool( _
        archetypeRef as ArchetypeType ptr)
	
	'[Internal] Invalidates cached queries that query on a component
	declare sub InvalidateCachedQueries( _
		componentID as ComponentIDType)
	
	'[Internal] Adds an archetype to the pair-to-archetype list
	'This list is maintained to properly delete pair-using archetypes
	'when the pair is deleted (such an entity with children being deleted)
	declare sub RegisterArchetypeUsingPair( _
		inPairID as ComponentIDType, _
		inArchetypeID as ArchetypeIDType)
	
	'[Internal] Deletes the archetype ID list from the pair-using archetype list.
	declare sub UnregisterArchetypeUsingPair( _
		inPairID as ComponentIDType, _
		inArchetypeID as ArchetypeIDType)
	
    '[Internal] Add an entity to an archetype
    'Also pushes the archetype into the componentID to archetype list
    'if it's the first entity in the archetype
    declare function AddEntityToArchetype( _
        inEntityID as EntityIDType, _
        inArchetypeID as ArchetypeIDType) as EntityLocationSpecifierType
    
    '[Internal] Delete an entity from an archetype
    'Does not delete the entity ID
    declare sub DeleteEntityFromArchetype( _
        byref inLocation as EntityLocationSpecifierType)
    
    '[Internal] Removes an entity ID from our internal structures
    'Increases the generation and adds it to our deleted entity ID list
    declare sub RemoveEntityID( _
        inEntityID as EntityIDType)
    
    'Recursively deletes archetypes holding children of a given entity ID
    declare sub DeleteChildrenRecursive( _
        inEntityID as EntityIDType)
    
    'Delete an entity
    declare sub DeleteEntity( _
        inEntityID as EntityIDType)
    
    '[Internal] Move an entity from its archetype to another one
    declare sub MoveEntity( _
        inEntityID as EntityIDType, _
        inNewArchetypeID as ArchetypeIDType)
    
    '[Internal] Sets an entity to be moved to another archetype.
    'This speeds up adding/removing components by a few order
    'of magnitude when adding/removing many components 
    'to many entities before actually using them
    declare sub DeferMoveEntity( _
        inEntityID as EntityIDType, _
        inArchetypeID as ArchetypeIDType)
    
    '[Internal] Adds a command to add data to a component for an entity
    'These commands will be executed in sequence, and there
    'can be multiple commands to set the same location of data
    'more than once.  It's up the the user not to facilitate such
    'a pattern in the first place.
    declare sub DeferMoveComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType, _
        inComponentSize as integer, _
        inComponentData as any ptr)
    
    '[Semi-Internal] Executes all deferred commands
    'End users should avoid needing this.  Use with caution
    declare sub FlushCommandBuffer()
    
    '[Internal] Adds the pending component data to the right place
    declare sub FlushMoveComponents()
    
	'[Internal] Calls the destructor on all component data arrays
	'in an archetype, if applicable.
	declare sub DestructArchetypeComponents( _
		inArchetypeRef as ArchetypeType ptr)
	
    '[Internal] Get the next available archetype ID
    declare function GetNextArchetypeID() as ArchetypeIDType
    
    '[Internal] Add an archetype, returns the new archetype ID
    declare function AddArchetype( _
        byref inComponentList as ComponentIDListType) as ArchetypeIDType
    
    '[Internal] Delete an archetype
    declare sub DeleteArchetype( _
        inArchetypeID as ArchetypeIDType)
    
    '[Internal] Return pointer to an archetype given an archetypeID
    declare function GetArchetypeByID( _
        inArchetypeID as ArchetypeIDType) as ArchetypeType ptr
    
	'[Internal] Checks if an archetype for a given component list exists.
	'If so return it.  If not, create one and return it
	declare function GetOrCreateArchetypeIDFromComponentList( _
		inComponentList as ComponentIDListType) as ArchetypeIDType
	
    '[Internal] In the case an entity is moved BUT the move hasn't been flushed yet,
    'the entity will actually point to the archetype in the DeferMoveDictionary,
    'rather than the one in our entity -> location mapping.
    'This is required to properly add/remove components with deferred move.
    declare function GetEntityActiveArchetype( _
        inEntityID as EntityIDType) as ArchetypeType ptr
    
    '[Internal] Sort archetype IDs by the sort index of a given component ID
    declare sub SortArchetypeIDQuery(_ 
        byref inArchetypeIDs as DynamicArrayType, _
        baseComponentID as ComponentIDType, _
        sortDirection as byte)
    
	'Sort the results of a query by a given component ID and direction
	declare sub SortQueryResultByComponent overload ( _
		byref inQuery as QueryType, _
		queryTerm as QueryTermType)
	
	'Sort the results of a quickView by a given component ID and direction
	declare sub SortQueryResultByComponent overload ( _
		byref inQuickView as QuickViewType, _
		queryTerm as QueryTermType)
	
	'Sets up a query to be cached
	declare sub RegisterCachedQuery( _
		inQuery as QueryType ptr)
	
	'Removes a query from the caching structures
	declare sub UnregisterCachedQuery( _
		inQuery as QueryType ptr)
	
    'Prepare a query for actual querying
    'Returns 0 if there's no entities matching, otherwise non 0
    declare function PrepareQuery overload ( _
        byref inQuery as QueryType) as integer
    
    'Gets the next component list from the next available archetype
    'Used to iterate over a query
    declare function QueryNext overload ( _
        byref inQuery as QueryType) as integer
    
    'Prepares a quick view
    'Returns 0 if there's no entities matching, otherwise non 0
    declare function PrepareQuery overload ( _
        byref inQuickView as QuickViewType) as integer
    
    'Gets the next component list from the next available archetype
    'Used to iterate over a quick view
    declare function QueryNext overload ( _
        byref inQuickView as QuickViewType) as integer
	
    'Restarts a query to be iterated over again
    declare sub RestartQuery overload ( _
        byref inQuery as QueryType)

    declare sub RestartQuery overload ( _
        byref inQuickView as QuickViewType)
	
	'[Internal] Returns a pointer to the pipeline for a phase
	declare function GetPhase( _
		inPhase as PhaseEnum) as DynamicArrayType ptr
	
	'[Internal] Adds a system to the specified phase
	declare sub AddSystem( _
		byref inSystem as SystemType ptr, _
		inPhase as PhaseEnum = UPDATE_PHASE)
	
    'Add a system to a phase with a tick update
    declare sub AddTickSystem( _
        byref inSystem as SystemType ptr, _
		inPhase as PhaseEnum = UPDATE_PHASE)
    
    'Add a system to a phase with an unbounded update
    declare sub AddUnboundedSystem( _
        byref inSystem as SystemType ptr, _
		inPhase as PhaseEnum = UPDATE_PHASE)
    
	'Add an event handler to a phase
	declare sub AddEventHandlerSystem( _
		inEventHandlerName as string, _
		inEventID as EventIDType, _
		inEventCallback as sub(FBECS_EVENT_CALLBACK_SIGNATURE), _
		inPhase as PhaseEnum = UPDATE_PHASE)
	
    'Manually run a system once
    declare sub RunSystem( _
        byref inSystem as SystemType, _
        delta as double = 0.0d)
    
	'Manually run an event handler once
	declare sub RunEventHandler( _
		byref inEventQueue as ECSEventQueueType, _
		inCallback as sub(FBECS_EVENT_CALLBACK_SIGNATURE), _
		delta as double = 0.0d)
	
    'Set the target fps for the system to run at
    declare sub SetSystemRefreshRate( _
        inRefreshRate as uinteger)
    
	'Enables/disables a system.  Systems are enabled by default on creation
	'0 = disabled, non-zero = enabled
	declare sub SetSystemEnabled( _
		byref inSystem as SystemType, _
		inEnabledFlag as ubyte)
	
	'Imports a module
	declare sub ImportModule( _
		inModuleCallback as sub(IMPORT_MODULE_PARAMETERS), _
		inModuleName as zstring ptr)
	
    'Run the systems
    declare sub Update()
    
    'Returns a string of a component converted to its Name, if available
    declare function ComponentIDHumanReadable( _
        componentID as ComponentIDType) as string
        
    'Returns a string of a component list where the IDs are
    'swapped for the component's name if provided
    declare function ComponentListHumanReadable( _
        byref inComponentList as ComponentIDListType) as string

    'Prints to LogStat the list of components attached
    'to a given entity
    declare sub ListEntityComponents( _
        byref inEntityID as EntityIDType)
    
    'Returns a string of an archetype similar to:
    '{id: <ID>, components: {<Component name list>}}
    declare function ArchetypeHumanReadable( _
        inArchetype as ArchetypeType ptr) as string
    
    'Prints to LogStat stats about number of archetypes and
    'count of entities in each archetype
    declare sub LogFragmentationStats()
	
	'Prints to LogStat the current pipeline
	declare sub LogPipeline()
	
	'Prints to LogStat the contents of the modules in import order
	declare sub LogModules()
    
end type

end namespace

#endif
