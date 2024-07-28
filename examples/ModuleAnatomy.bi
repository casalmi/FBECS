/'
'An example and explaination of what a typical FBECS module header might look like.

'Typical ifdef guard
#ifndef ModuleAnatomy_bi
#define ModuleAnatomy_bi

'Include whatever headers you might need
#include once "../src/utilities/Vector3D.bi"
#include once "../src/classes/Mesh.bi"
'...etc

'Including the library header is mandatory:
#include once "../src/FBECS/FBECS.bi"

'Subsequently, include headers to other modules that this one uses
'#include once "../../ECSModules/SomeOtherModule.bi"
'...etc

namespace ModuleAnatomy
'A namespace for things you want this module to expose.

'Declared extern as the definition will be within the associated .bas
extern Stuff as single
'... etc

'Also include any functions you want this module to expose
declare sub SetStuff(inVal as single)

end namespace

'Declare your component types!
'If possible, keep your components un-complicated to avoid
'extra work for you.
'If your type needs more than the default constructor/destructor/copy assign operator,
'then you must declare them yourself.  Specifically, you must define:
'declare Constructor() 'Must not take parameters
'declare Destructor()
'declare operator Let(byref rhs as ECS_TYPE(MyComponent)) 'This must be a deep copy
'
'Note: Components should NOT have functions/subs/properties declared!
'It is the job of the system, not the component, to manipulate the
'component's data.  Exceptions to this rule will be -rare-.

'A typical non-complicated type:
type ECS_TYPE(PositionComponent)
	dim as Vector3DType Position
end type

type ECS_TYPE(SphereCollisionComponent)
	dim as single Radius
end type

'A complicated type requiring lifetime functions:
type ECS_TYPE(MeshComponent)
	dim as MeshType ptr Mesh

	declare constructor()
	declare destructor()
	declare operator Let(byref rhs as ECS_TYPE(MeshComponent))
end type

'Typedefs also work, but you must have generated autohooks for the base type
'All default freebasic types have autohooks automatically generated, you only
'need to generate them if you're using a UDT
'However, I recommend you keep all your AutoHooks generations in a separate header
DECLARE_HOOKS(Vector3DType)
type ECS_TYPE(VelocityComponent) as Vector3DType

'Events can also have associated types
'Note: If the event does not have an associated type,
'you can only ever enqueue up to 1 instance of that event
'at any given time.
type ECS_TYPE(CollisionEvent)
	dim as FBECS.EntityIDType EntityA
	dim as FBECS.EntityIDType EntityB
end type

'Singleton types are created the same way as components
'I refer to singletons as resources, as the ECS keeps and provides these values
'Singletons (resources) are not meant to be added to entities
type ECS_TYPE(GravityResource)
	dim as const single Value = -9.81s
end type

'After the types are declared, we must declare the components themselves
ECS_DECLARE_COMPONENT(PositionComponent)
ECS_DECLARE_COMPONENT(SphereCollisionComponent)
ECS_DECLARE_COMPONENT(MeshComponent)
ECS_DECLARE_COMPONENT(VelocityComponent)
ECS_DECLARE_COMPONENT(GravityResource)

'Also declare events
ECS_DECLARE_EVENT(CollisionEvent)

'Now we will declare any tags we might want
'Tags are components that do not have an associated type
'Events without a type can also be declared in this fashion
ECS_DECLARE_COMPONENT(VisibleTag)

'We then declare the module
'I recommend naming your module the same way as the file itself
'I usually add the "Module" suffix to the name
ECS_DECLARE_MODULE(ModuleAnatomyModule)

#endif
'/
