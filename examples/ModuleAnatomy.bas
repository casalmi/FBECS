/'
'An example and explaination of what a typical FBECS module source file might look like.

'Typical ifdef guard
#ifndef ModuleAnatomy_bas
#define ModuleAnatomy_bas

'Include the module header
#include once "ModuleAnatomy.bi"

'Include any other headers that are needed for the source file,
'but weren't needed in the header.  This may include other module headers
#include once "SomeOtherModule.bi"

namespace ModuleAnatomy
    'Define your variables/functions you want this module to expose
    dim Stuff as single = 42.0s
    
    sub SetStuff(inVal as single)
        ModuleAnatomy.Stuff = inVal
    end sub

end namespace

'Define any component lifetimes related members
'(And, if applicable, the rare component sub/function/property)
constructor ECS_TYPE(MeshComponent)
    this.Mesh = new MeshType()
end constructor

destructor ECS_TYPE(MeshComponent)
    if this.Mesh then
        delete(this.Mesh)
        this.Mesh = 0
    end if
end destructor

operator ECS_THYPE(MeshComponent).Let(byref rhs as ECS_TYPE(MeshComponent))
    this.Mesh = rhs.Mesh.Copy()
end operator

'Define the components
ECS_DEFINE_COMPONENT(PositionComponent)
ECS_DEFINE_COMPONENT(SphereCollisionComponent)
ECS_DEFINE_COMPONENT(MeshComponent)
ECS_DEFINE_COMPONENT(VelocityComponent)
ECS_DEFINE_COMPONENT(GravityResource)

'Define events
ECS_DEFINE_EVENT(CollisionEvent)

'Define the tags as well
ECS_DEFINE_COMPONENT(VisibleTag)

'Now we will declare all the systems and event handlers we might need
ECS_DECLARE_SYSTEM(ApplyGravitySystem)
ECS_DECLARE_SYSTEM(UpdatePositionSystem)
ECS_DECLARE_SYSTEM(CheckCollisionSystem)
ECS_DECLARE_EVENT_HANDLER(HandleCollisions)
ECS_DECLARE_SYSTEM(RenderMeshSystem)

'Now we will create the module import sub
'The module signature defines a single parameter:
'byref inECS as FBECS.ECSInstanceType
'The FBECS instance will be passed to this module
'when imported
sub ECS_MODULE_SIGNATURE(ModuleAnatomyModule)

    'Register all components and events
    
    'A component is a singleton when registered as one
    '(You could techinically do this yourself by adding the component to itself, but why?)
    ECS_REGISTER_SINGLETON(inECS, GravityResource)
    
    ECS_REGISTER_COMPONENT(inECS, GPositionComponent)
    ECS_REGISTER_COMPONENT(inECS, GSphereCollisionComponent)
    ECS_REGISTER_COMPONENT(inECS, GMeshComponent)
    ECS_REGISTER_COMPONENT(inECS, GVelocityComponent)

    ECS_REGISTER_COMPONENT(inECS, GVisibleTag)

    ECS_REGISTER_EVENT(inECS, GCollisionEvent)

    'Register your systems
    'A system will only run if all of its query terms are satisfied
    'The order of the system run depends first on the PHASE, and second
    'on the order in which it was added.  Event handlers and systems
    'share the same ordering criteria and will run in order of
    'declaration (within the PHASE, of course)
    
    'The difference between unbounded and tick systems:
    'Unbounded runs every time the Update() function is called
    'Tick system runs every time the refresh rate timer is ticked
    '(that value is configurable and defaults to 1/60)

    'Note that the query terms are wrapped in (), this is
    'because the term is not just a componentID, but a (componentID, QueryOperatorEnum)
    'tuple.  e.g. (VelocityComponent, FBECS._ANDNOT
    'See QueryIterator.bi for the enum list

    'Component order does matter for querying
    'I recommend ordering components first on those that have types, then on tags
    ECS_ADD_TICK_SYSTEM(inECS, , ApplyGravitySystem, _
        (VelocityComponent))

    ECS_ADD_UNBOUNDED_SYSTEM(inECS, , UpdatePositionSystem, _
        (PositionComponent), (VelocityComponent))

    ECS_ADD_UNBOUNDED_SYSTEM(inECS, , CheckCollisionSystem, _
        (PositionComponent), (SphereCollisionComponent))
    
    ECS_ADD_EVENT_HANDLER_SYSTEM(inECS, CollisionEvent, HandleCollisions)

    ECS_ADD_UNBOUNDED_SYSTEM(inECS, , RenderMeshSystem, _
        (PositionComponent), (MeshComponent), (VisibleTag))

end sub

'Now define the systems and event handlers
'
'Systems have the following signature
'byref inECS as FBECS.__ECSInstanceType, _ 'The ECS instance
'byref inQuery as FBECS.QueryType, _ 'The query for this system
'deltaTime as double 'The delta time
sub ECS_SYSTEM_SIGNATURE(ApplyGravitySystem)
    
    'Get your resources
    var gravity = ECS_GET_SINGLETON(inECS, GravityResource)

    'Set up the type to iterate over
    dim _velocity as ECS_TYPE(VelocityComponent) ptr

    'A typical query iteration will look like so
    while inECS.QueryNext(inQuery)
    
        'It is important that you align the argument
        'index with how it was ordered in the system declaration
        _velocity = inQuery.GetArgumentArray(0)

        for i as integer = 0 to inQuery.NodeCount - 1

            'I like to do this for convenience
            var byref velocity = _velocity[i]
            
            velocity[1] += gravity * deltaTime

        next
    wend

end sub

sub ECS_SYSTEM_SIGNATURE(UpdatePositionSystem)
    
    dim _position as ECS_TYPE(PositionComponent) ptr
    dim _velocity as ECS_TYPE(VelocityComponent) ptr

    while inECS.QueryNext(inQuery)
        'Again note that the component order at system declaration
        'is what determines the argument array index for the components
        _position = inQuery.GetArgumentArray(0)
        _velocity = inQuery.GetArgumentArray(1)
        
        for i as integer = 0 to inQuery.NodeCount - 1

            var byref position = _position[i]
            var byref velocity = _velocity[i]
            
            position.Position += velocity

        next
    wend

end sub

sub ECS_SYSTEM_SIGNATURE(CheckCollisionSystem)
    
    dim _position as ECS_TYPE(PositionComponent) ptr
    dim _coll as ECS_TYPE(SphereCollisionComponent) ptr

    dim e as ECS_TYPE(CollisionEvent)

    while inECS.QueryNext(inQuery)
        
        _position = inQuery.GetArgumentArray(0)
        _coll = inQuery.GetArgumentArray(1)

        for i as integer = 0 to inQuery.NodeCount - 1
            
            var byref position = _position[i]
            var byref coll = _coll[i]

            'At some point you figure out how to do this...
            
            e.EntityA = inQuery.GetEntity(i)
            e.EntityB = otherEntityID
            ECS_ENQUEUE_EVENT_W_VALUE(inECS, CollisionEvent, e)

        next
    wend
end sub

'Event handlers have the following signature
'byref inECS as FBECS.__ECSInstanceType, _ 'The FBECS instance
'byref inEvents as DynamicArrayType, _ 'The array of events
'deltaTime as double 'Delta time passed
sub ECS_EVENT_HANDLER_SIGNATURE(HandleCollisions)
    
    'A typical event handler iteration will look like this
    'This macro reads like:
    'For each events as ECS_TYPE(CollisionEvent) in inEvents
    FOR_IN(events, ECS_TYPE(CollisionEvent), inEvents)
        
        'Event queues are deleted after being handled by an event handler
        'If you wish for an event to continue after this handler, you must 
        'COPY and then RE-ENQUEUE the event
        'It would look like this:
        'dim e as ECS_TYPE(CollisionEvent)
        'e = events 'Deep copy the event
        'ECS_ENQUEUE_EVENT_W_VALUE(inECS, CollisionEvent, e) 'Re-enqueue the event

        'Handle the events...
        HandleCollisions(events.EntityA, events.EntityB)
    FOR_IN_NEXT

end sub

'You get the idea...
sub ECS_SYSTEM_SIGNATURE(RenderMeshSystem)
    
    dim _position as ECS_TYPE(PositionComponent) ptr
    dim _mesh as ECS_TYPE(MeshComponent) ptr

    while inECS.QueryNext(inQuery)
        
        _position = inQuery.GetArgumentArray(0)
        _mesh = inQuery.GetArgumentArray(1)
        'Note that the VisibleTag does not have values associated with it
        'we ignore it entirely here in the query iteration

        for i as integer = 0 to inQuery.NodeCount - 1
            
            var byref position = _position[i]
            var byref mesh = _mesh[i]
            
            RenderMesh(position.Position, mesh.Mesh)

        next
    wend

end sub

#endif
'/
