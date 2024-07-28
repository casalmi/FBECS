/' 'Example of a source file that utilizes an FBECS module

#include once "Main.bi"

dim ECSInstance as FBECS.ECSInstanceType

ECS_IMPORT_MODULE(ECSInstance, ModuleAnatomyModule)

'Do whatever setup you need to do
dim defaultMesh as MeshType = LoadMesh(...)
'etc...

'Set up your entities
dim e as FBECS.EntityIDType

dim position as ECS_TYPE(PositionComponent)
dim velocity as ECS_TYPE(VelocityComponent)
dim coll as ECS_TYPE(SphereCollisionComponent)
dim mesh as ECS_TYPE(MeshComponent)

mesh.Mesh = @defaultMesh
coll.Radius = 2.0

for i as integer = 0 to 9
	
	position.Position = Vector3DType(rnd() * 10, rnd() * 10, rnd() * 10)
	velocity = Vector3DType(rnd() * 2, 0.0, rnd() * 2)
	
	e = ECSInstance.CreateNewEntity()
	'Components are copied on add, not moved like events
	ECS_ADD_COMPONENT_W_VALUE(ECSInstance, e, PositionComponent, position)
	ECS_ADD_COMPONENT_W_VALUE(ECSInstance, e, VelocityComponent, velocity)
	ECS_ADD_COMPONENT_W_VALUE(ECSInstance, e, SphereCollisionComponent, coll)
	ECS_ADD_COMPONENT_W_VALUE(ECSInstance, e, MeshComponent, mesh)
	
	'Tags don't have values
	ECS_ADD_COMPONENT(ECSInstance, e, VisibleTag)

next

while NOT MultiKey(FB.SC_ESCAPE)
	
	'Handle whatever you need to before updating

	'Update one frame
	ECSInstance.Update()
	
	'Handle any post-updating stuff you need to, like flipping frame buffers
	flip()

wend
'/
