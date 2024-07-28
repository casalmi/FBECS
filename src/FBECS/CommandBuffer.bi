#ifndef CommandBuffer_bi
#define CommandBuffer_bi

#include once "../utilities/Dictionary.bi"
#include once "../utilities/DynamicArray.bi"
#include once "Entity.bi"
#include once "Component.bi"
#include once "Archetype.bi"

namespace FBECS

DEFINE_DICTIONARY_TYPE(FBECS.EntityIDType, byte, DictionaryType_EntIDByte)
DEFINE_DICTIONARY_TYPE(FBECS.EntityIDType, FBECS.ArchetypeType ptr, DictionaryType_EntIDArchPtr)

type ECSCommandBufferType
    
    enum CommandEnum
        ADD_COMPONENT    = 1
        REMOVE_COMPONENT = 2
    end enum

    type CreateEntityContainerType

        dim as EntityIDType EntityID
        dim as ArchetypeIDType ArchetypeID
        
    end type

    type AddChildOfArgsType

        dim as EntityIDType ChildID
        dim as EntityIDType ParentID

    end type

    type MoveComponentContainerType
        
        dim as EntityIDType EntityID
        dim as ComponentIDType ComponentID
        dim as uinteger<32> Size
        
    end type

    type AddRemoveComponentArgsType
        
        dim as EntityIDType EntityID
        dim as ComponentIDType ComponentID
        dim as uinteger<32> Command
        
    end type

    
    'Give some default sizes to minimize memory allocations/frees
    'when there are only small changes
    const MIN_DEFER_ADDREMOVE_COMPONENT_COUNT as integer = 16
    const MIN_DEFER_DELETE_ENTITY_COUNT as integer = 8
    const MIN_DEFER_CREATE_ENTITY_COUNT as integer = 8
    const MIN_DEFER_ADD_CHILD_OF_COUNT as integer = 8
    const MIN_DEFER_MOVE_COMPONENT_SIZE as integer = 1 SHL 20 '1 MB
    const MIN_DEFER_DELETE_ARCHETYPE_COUNT as integer = 4
    const MIN_DEFER_DELETE_PAIR_COUNT as integer = 4
    
    'Flag to determine whether or not we should execute on this buffer
    dim as uinteger<32> HasCommands
    
	'List of components to add/remove to/from an entity
    dim as DynamicArrayType DeferAddRemoveComponentList = _
        DynamicArrayType(sizeof(AddRemoveComponentArgsType), MIN_DEFER_ADDREMOVE_COMPONENT_COUNT)
    
	'List of entities to create
	'Despite the fact that entities first get shoved into the null archetype,
	'the location dictionary is still modified by this, so we need to defer it.
	'List of entities marked for deletion
    dim as DynamicArrayType DeferCreateEntityList = _
        DynamicArrayType(sizeof(CreateEntityContainerType), MIN_DEFER_CREATE_ENTITY_COUNT)

    dim as DynamicArrayType DeferAddChildOfList = _
        DynamicArrayType(sizeof(AddChildOfArgsType), MIN_DEFER_ADD_CHILD_OF_COUNT)
	
    'List of entities marked for deletion
    dim as DynamicArrayType DeferDeleteEntityList = _
        DynamicArrayType(sizeof(EntityIDType), MIN_DEFER_DELETE_ENTITY_COUNT)
    
    'Dictionary mapping entity -> eventual archetype on flush
    dim as DictionaryType_EntIDArchPtr DeferMoveEntityDictionary
    
    'Array of component data used for a defer move
    'This is not used as a normal DynamicArrayType and is instead manually upkept
    'Currently set to 1MB
    dim as DynamicArrayType DeferMoveComponentList = _
        DynamicArrayType(sizeof(ubyte), MIN_DEFER_MOVE_COMPONENT_SIZE)
    
    'List of archetypes to delete
    dim as DynamicArrayType DeferDeleteArchetypeList = _
        DynamicArrayType(sizeof(ArchetypeIDType), MIN_DEFER_DELETE_ARCHETYPE_COUNT)
   
    'List of pair components to create
	dim as DictionaryType_EntIDByte DeferredPairComponents

    dim as DynamicArrayType DeferDeletePairComponentList = _
        DynamicArrayType(sizeof(ComponentIDType), MIN_DEFER_DELETE_PAIR_COUNT)
	
	'Array of entities to insert into the system
	declare sub DeferCreateEntity( _
		inEntityID as EntityIDType, _
		inArchetypeID as ArchetypeIDType)
	
    'Mark an entity for deletion
    declare sub DeferDeleteEntity( _
        inEntityID as EntityIDType)
    
    'Mark an entity to change archetypes
    declare sub DeferMoveEntity( _
        inEntityID as EntityIDType, _
        archetypeRef as ArchetypeType ptr)

    'Defer AddChildOf so it can be called on not-yet-existing entities
    declare sub DeferAddChildOf( _
        inChildID as EntityIDType, _
        inParentID as EntityIDType)
    
    declare sub DeferAddRemoveComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType, _
        inCommand as CommandEnum)
    
    'Create the move component container and return a pointer to the
    'segment of memory to copy the data to
    declare function DeferMoveComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType, _
        inComponentSize as integer) as ubyte ptr
    
    'Some archetypes can be deleted and we have to hold off on changing them
    'until we flush the commands
    declare sub DeferDeleteArchetype( _
        inArchetypeID as ArchetypeIDType)

    'Pair components can be deleted, particularly ChildOf pairs
    declare sub DeferDeletePairComponent( _
        inPairComponent as ComponentIDType)
    
    'Reset the command buffer
    declare sub Empty()
    
end type

end namespace

#endif
