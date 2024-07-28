
#include "fbgfx.bi"

#libpath "../src/FBECS/"
#inclib "FBECS"
#include "../src/FBECS/FBECS.bi"

'Components are just types!
'The ECS_TYPE() macro expands the name of the component
'into a mangled type identifier.  This is necessary to keep
'the bookkeeping straight and to be able to refer to the 
'component itself directly by name.  In this case, you will
'need to understand the following distinction:
'
'PositionComponent: A FBECS.ComponentIDType, used to refer to the component in the ECS
'ECS_TYPE(PositionComponent): The name of the Type struct used to declare variables
'RECOMMENDATION: Use the following suffix naming scheme:
' ...Component: When the component is not special in any way
' ...Resource: When the component is meant to be accessed by
'              systems, but not attached to entities
' ...Hook: When the component is accessed by systems, but is
'          updated outside the ECS ecosystem (outside systems/event handlers)
' ...CEvent: When the component is meant to be attached to an
'            entity only to be updated and promptly removed.
'            These should not be favored over proper events.
' ...Tag: When the component does not have a Type.
' ...Event: When the event is an actual FBECS.EventType.
type ECS_TYPE(PositionComponent)
	dim as single x,y
end type

type ECS_TYPE(VelocityComponent)
	dim as single x,y
end type

'This is a proper event.  This behaves differently from
'components as it's a use once and discard construct.
'Events are meant to avoid the necessity of CEvents
type ECS_TYPE(SpawnPawnEvent)
	dim as integer<32> x,y
end type

'Instantiate the ECS!
'You only need one.  Do not create more unless you're insane
dim ECSInstance as FBECS.ECSInstanceType

'Bootstrap components

'First, they must be declared
'This is usually done in the header (.bi) part of a module
ECS_DECLARE_COMPONENT(PositionComponent)
ECS_DECLARE_COMPONENT(VelocityComponent)
'Same with events
ECS_DECLARE_EVENT(SpawnPawnEvent)

'Next, they are defined
'This is usually done in the source (.bas) part of a module
ECS_DEFINE_COMPONENT(PositionComponent)
ECS_DEFINE_COMPONENT(VelocityComponent)
'Same with events
ECS_DEFINE_EVENT(SpawnPawnEvent)

'Finally, they are registered
'This is usually done in the module import function,
'which would be defined in the source (.bas) part of a module
ECS_REGISTER_COMPONENT(ECSInstance, PositionComponent)
ECS_REGISTER_COMPONENT(ECSInstance, VelocityComponent)
'Same with events
ECS_REGISTER_EVENT(ECSInstance, SpawnPawnEvent)

'Declare systems and event handlers
'This is usually done in the source (.bas) part of the module
ECS_DECLARE_SYSTEM(UpdatePosition)
ECS_DECLARE_SYSTEM(DrawPawns)
ECS_DECLARE_EVENT_HANDLER(SpawnPawns)

'SYSTEM ORDER IS IMPORTANT!
'When systems are added to the ECS, they will be run:
'First in order of their phase and
'Second in order of their being added
'In this example, I have the UpdatePosition system being
'added before the SpawnPawns event handler, but because the
'SpawnPawns event handler is in the LOAD_PHASE which comes
'before the UPDATE_PHASE, the SpawnPawns event handler will be
'run first.  System order must be kept in mind when adding systems.

'Add a system to the ECS instance
'This is usually done in the module import function
'This system queries on two components position and velocity
'When passed as an argument to this macro, it expects a QueryTermType,
'which is defined in QueryIterator.bi
'A query term type is created with the default constructor of:
'(ComponentID, QueryOperatorEnum).  The default QueryOperatorEnum
'is equivalent to ECSInstance._AND, meaning the component must appear
'in an archetype for it to be iterated over in this system.
'The only other valid value is ECSInstance._ANDNOT (must not appear)
'
'Furthermore, component order is important!
'It will determine the index you will use to access the
'component when you implement the system.  Specifically, when
'you iterate over the system's query.  The components are 0 indexed.
ECS_ADD_UNBOUNDED_SYSTEM(ECSInstance, , UpdatePosition, _
	(PositionComponent), (VelocityComponent))

'Draw some pawns.  We only need the position for this
ECS_ADD_UNBOUNDED_SYSTEM(ECSInstance, ECSInstance.SAVE_PHASE, DrawPawns, _
	(PositionComponent))
	
'Event handlers will iterate over the event once and discard it when
'the event handler finishes.  They are treated like systems with respect to ordering.
ECS_ADD_EVENT_HANDLER_SYSTEM(ECSInstance, ECSInstance.LOAD_PHASE, SpawnPawnEvent, SpawnPawns)

'Now implement the system (systems are subs, not functions)
'This is where the fun happens!
'A system has the following signature:
' - byref inECS as FBECS.__ECSInstanceType: The ECS instance calling this system
' - byref inQuery as FBECS.QueryType: The query used to match on this system
' - deltaTime as double: The delta time passed since last update
sub ECS_SYSTEM_SIGNATURE(UpdatePosition)
	
	'The query will return arrays of the types of components
	'You'll iterate over them via pointer access of the array itself
	'Remember that this is where you use the ECS_TYPE() macro
	'RECOMMENDATION: Follow this naming pattern:
	' Underscore (_) prefix the pointer array
	dim _position as ECS_TYPE(PositionComponent) ptr
	dim _velocity as ECS_TYPE(PositionComponent) ptr
	
	'Iterate over the query and do the work.
	'Note that it is the ECS handling the query's archetype iteration, not
	'the query handling the iteration
	'
	'When iterating over a query, you will be iterating over two different constructs.
	'- The first construct is the Archetype (see: src/FBECS/Archetype.[bi/bas] for Type details)
	'Every archetype that matches on your query (and there will likely be many) will
	'be iterated over here in the outer while loop.  Each archetype holds AT LEAST the
	'components you queried on, and possibly more
	'The second construct is the components.
	'This will simply be a tightly packed array of the components you've created.
	while inECS.QueryNext(inQuery)
		
		'Accessing the components you queried on uses this "GetArgumentArray" function
		'It take the index of the component you defined back in ECS_ADD_UNBOUNDED_SYSTEM,
		'and returns a pointer to an array of that component.  That array lives in the archetype.
		'I specified PositionComponent first, so the PositionComponent in the query is at index 0 (zero indexed)
		'WARNING: There is no type checking done here; it is up to you to get the index right!
		_position = inQuery.GetArgumentArray(0)
		_velocity = inQuery.GetArgumentArray(1)
		
		'It is possible to check here if an archetype contains another component.
		'In that case (though it's _not_ often you will need to do this) you can use
		'e.g.: inQuery.GetComponentArray(SomeComponent) and check if the resulting pointer
		'is null or not.  If it's not null, that means that the archetype had SomeComponent
		'in it and you can use that array however you want.
		
		'Now that we have the arrays, we will iterate over the components.
		'Note that it is the Query that keeps the node count, 0 indexed (thus -1)
		for i as integer = 0 to inQuery.NodeCount - 1
			
			'RECOMMENDATION: Follow this naming pattern:
			' Create a byref value of the component using the same name as the array ptr
			'Note that the pointers are accessed as you'd expect to access any ptr array
			var byref position = _position[i]
			var byref velocity = _velocity[i]
			
			'Now do whatever you need to do with these components
			'This is a rather simple example.
			
			position.x += velocity.x * deltaTime
			position.y += velocity.y * deltaTime
			
			'Do some collision detection
			if position.x < 0.0 ORELSE position.x > 800.0 then
				velocity.x *= -1
			end if
			
			if position.y < 0 ORELSE position.y > 600.0 then
				velocity.y *= -1
			end if
			
		next
		
	wend
	
end sub

sub ECS_SYSTEM_SIGNATURE(DrawPawns)
	
	'System presented without comment, see if you can understand it.
	
	dim _position as ECS_TYPE(PositionComponent) ptr
	
	while inECS.QueryNext(inQuery)
		
		_position = inQuery.GetArgumentArray(0)
		
		for i as integer = 0 to inQuery.NodeCount - 1
			
			var byref position = _position[i]
			
			Circle (cast(integer, position.x), cast(integer, position.y)), 10
			
		next
		
	wend
	
end sub

'Implement an event handler
'Event handlers have the following signature:
' - byref inECS as FBECS.__ECSInstanceType: The ECS instance calling this system
' - byref inEvents as DynamicArrayType: The array of events passed into this event handler
' - deltaTime as double: The delta time passed since last update
sub ECS_EVENT_HANDLER_SIGNATURE(SpawnPawns)
	
	'The entity ID handle (that's all an entity actually is: an integer<64>)
	dim entityID as FBECS.EntityIDType
	
	'These will be used to populate position and velocity components
	'Note how this uses the ECS_TYPE() macro again
	dim position as ECS_TYPE(PositionComponent)
	dim velocity as ECS_TYPE(VelocityComponent)
	
	'Event handlers are very simple.
	'RECOMMENDATION: Use the FOR_IN macro to iterate over events
	'See: src/utilities/DynamicArrayListComprehension.bi for usage
	'Or just copy what I'm doing.
	FOR_IN(events, ECS_TYPE(SpawnPawnEvent), inEvents)
		
		'Since events are both MOVED resources and one and done,
		'if you want another event handler to see this event, you must:
		'1) Make a local copy of the event and
		'2) Re-enqueue the event with the local copy.  This will place it into a
		' temporary place and it can be picked up by other event handlers
		
		position.x = events.x
		position.y = events.y
		
		velocity.x = (rnd() * 100.0) - 50.0f
		velocity.y = (rnd() * 100.0) - 50.0f
		
		'Create a new entity
		entityID = inECS.CreateNewEntity()
		
		'Add components to the new entity
		'Components can be added with or without values.
		'Components added without values will be default constructed.
		
		'See: src/FBECS/ECSAPIMacros.bi for usage of this macro.
		'Note how PositionComponent is referred to directly by name, not through a macro
		'Note that components are COPIED, not moved.
		ECS_ADD_COMPONENT_W_VALUE(inECS, entityID, PositionComponent, position)
		ECS_ADD_COMPONENT_W_VALUE(inECS, entityID, VelocityComponent, velocity)
		
		'These entities will not exist until the command queue is flushed.
		'This can be done manually (but you SHOULDN'T unless you know how to use it)
		'but it will otherwise be done after the system/event handler has returned.
		
	FOR_IN_NEXT
	
end sub

'Do some setup stuff
'You can put this kind of setup into systems if you want, it's up
'to you how to architect resources that exist outside the ECS

ScreenRes 800, 600, 32, 2
ScreenSet 1,0

'Enqueue some spawn pawn events
scope
	dim spawnEvent as ECS_TYPE(SpawnPawnEvent)
	for i as integer = 0 to 9
		spawnEvent.x = rnd() * 750
		spawnEvent.y = rnd() * 550
		
		'See: src/FBECS/ECSAPIMacros.bi for usage of this macro.
		'WARNING: Events are MOVED when enqueued.  This means that the contents
		'of the spawnEvent will be cleared (default constructed) after calling
		'this enqueue.  The contents will have been "moved" into the ECS, and
		'you are no longer in control of them here.
		ECS_ENQUEUE_EVENT_W_VALUE(ECSInstance, SpawnPawnEvent, spawnEvent)
		
		'At this point, spawnEvent.x and .y should be 0 as the data was moved
		
	next

end scope

'Use ESC to exit
while NOT MultiKey(FB.SC_ESCAPE)
	
	'Since the screen is outside the ECS, I am CHOOSING
	'to update the screen outside the ECS update.  You may
	'instead do this in a system if you wish.
	cls
	
	'Iterate through the ECS systems
	ECSInstance.Update()
	
	flip
	
	sleep 1.0
	
wend