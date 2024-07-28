#ifndef CommandBuffer_bas
#define CommandBuffer_bas

#include once "FBECS.bi"

namespace FBECS

GENERATE_DICTIONARY_TYPE(FBECS.EntityIDType, byte, DictionaryType_EntIDByte)
GENERATE_DICTIONARY_TYPE(FBECS.EntityIDType, FBECS.ArchetypeType ptr, DictionaryType_EntIDArchPtr)

sub ECSCommandBufferType.DeferCreateEntity( _
		inEntityID as EntityIDType, _
		inArchetypeID as ArchetypeIDType)
	
	this.HasCommands += 1
	
	dim as ECSCommandBufferType.CreateEntityContainerType createContainer
	
	createContainer.EntityID = inEntityID
	createContainer.ArchetypeID = inArchetypeID
	
	this.DeferCreateEntityList.PushUDT(@createContainer)
	
end sub

sub ECSCommandBufferType.DeferDeleteEntity( _
        inEntityID as EntityIDType)
    
    this.HasCommands += 1
    
    this.DeferDeleteEntityList.PushUDT(@inEntityID)

end sub

sub ECSCommandBufferType.DeferMoveEntity( _
        inEntityID as EntityIDType, _
        archetypeRef as ArchetypeType ptr)
    
    this.HasCommands += 1
    
    this.DeferMoveEntityDictionary[inEntityID] = archetypeRef

end sub

sub ECSCommandBufferType.DeferAddChildOf( _
		inChildID as EntityIDType, _
		inParentID as EntityIDType)

	this.HasCommands += 1
	
	dim as ECSCommandBufferType.AddChildOfArgsType args
	
	args.ChildID = inChildID
	args.ParentID = inParentID
	
	this.DeferAddChildOfList.PushUDT(@args)

end sub

sub ECSCommandBufferType.DeferAddRemoveComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType, _
        inCommand as CommandEnum)
    
    this.HasCommands += 1
    
    dim as ECSCommandBufferType.AddRemoveComponentArgsType args
    
    args.EntityID = inEntityID
    args.ComponentID = inComponentID
    args.command = inCommand
    
    this.DeferAddRemoveComponentList.PushUDT(@args)
    
end sub

function ECSCommandBufferType.DeferMoveComponent( _
        inEntityID as EntityIDType, _
        inComponentID as ComponentIDType, _
        inComponentSize as integer) as ubyte ptr
    
    this.HasCommands += 1
    
    dim neededSize as integer
    
    dim srcPtr as any ptr
    dim dstPtr as any ptr
    
    dim retVal as ubyte ptr
    
    dim moveContainer as ECSCommandBufferType.MoveComponentContainerType
    
    moveContainer.EntityID = inEntityID
    moveContainer.ComponentID = inComponentID
    moveContainer.Size = inComponentSize
    
    with this.DeferMoveComponentList
        
        neededSize = .Count + sizeof(ECSCommandBufferType.MoveComponentContainerType) + inComponentSize
        
        'Check if we need to resize our command buffer
        if neededSize >= .Size then
            'Double the current size
            dim newSize as uinteger<32> = iif(.Size = 0, 1, .Size SHL 1)
            
            if newSize < neededSize then
                LogError( _
                    !"Could not resize the move component buffer.\n"; _
                    "Doubled size: ";newSize;!"\n"; _
                    "Needed  size: ";neededSize)
                return 0
            end if
            
            .Resize(newSize)
            
        end if
        
        srcPtr = @moveContainer
        dstPtr = @this.DeferMoveComponentList[.Count]
        
        memcpy(dstPtr, srcPtr, sizeof(ECSCommandBufferType.MoveComponentContainerType))
        
        .Count += sizeof(ECSCommandBufferType.MoveComponentContainerType)
        
        retVal = @this.DeferMoveComponentList[.Count]
        
        .Count += inComponentSize

    end with

    'Return the space to copy the component data to
    return retVal

end function

sub ECSCommandBufferType.DeferDeleteArchetype( _
        inArchetypeID as ArchetypeIDType)
    
    this.HasCommands += 1
    
    this.DeferDeleteArchetypeList.PushUDT(@inArchetypeID)

end sub

sub ECSCommandBufferType.DeferDeletePairComponent( _
        inPairComponent as ComponentIDType)

    this.HasCommands += 1

    this.DeferDeletePairComponentList.PushUDT(@inPairComponent)
    
end sub

sub ECSCommandBufferType.Empty()
    
    'Either resize the buffers back to their minimum size, or 0 out the contents
    
    if this.DeferAddRemoveComponentList.Count > this.MIN_DEFER_ADDREMOVE_COMPONENT_COUNT then
       this.DeferAddRemoveComponentList.ResizeNoSave(this.MIN_DEFER_ADDREMOVE_COMPONENT_COUNT)
    else
        memset( _
            @this.DeferAddRemoveComponentList[0], _
            0, _
            this.DeferAddRemoveComponentList.Count * sizeof(ECSCommandBufferType.AddRemoveComponentArgsType))
        this.DeferAddRemoveComponentList.Count = 0
    end if
    
	if this.DeferCreateEntityList.Count > this.MIN_DEFER_CREATE_ENTITY_COUNT then
        this.DeferCreateEntityList.ResizeNoSave(this.MIN_DEFER_CREATE_ENTITY_COUNT)
    else
        memset(@this.DeferCreateEntityList[0], 0, this.DeferCreateEntityList.Count * sizeof(ECSCommandBufferType.CreateEntityContainerType))
        this.DeferCreateEntityList.Count = 0
    end if
	
    if this.DeferDeleteEntityList.Count > this.MIN_DEFER_DELETE_ENTITY_COUNT then
        this.DeferDeleteEntityList.ResizeNoSave(this.MIN_DEFER_DELETE_ENTITY_COUNT)
    else
        memset(@this.DeferDeleteEntityList[0], 0, this.DeferDeleteEntityList.Count * sizeof(EntityIDType))
        this.DeferDeleteEntityList.Count = 0
    end if

    this.DeferMoveEntityDictionary.Empty()
    
	if this.DeferAddChildOfList.Count > this.MIN_DEFER_ADD_CHILD_OF_COUNT then
        this.DeferAddChildOfList.ResizeNoSave(this.MIN_DEFER_ADD_CHILD_OF_COUNT)
    else
        memset(@this.DeferAddChildOfList[0], 0, this.DeferAddChildOfList.Count * sizeof(ECSCommandBufferType.AddChildOfArgsType))
        this.DeferAddChildOfList.Count = 0
    end if
	
	'We do not want to re-allocate large segments too often
    'We can just overwrite the contents if the component list hasn't grown
    if this.DeferMoveComponentList.Count > this.MIN_DEFER_MOVE_COMPONENT_SIZE then
        this.DeferMoveComponentList.ResizeNoSave(this.MIN_DEFER_MOVE_COMPONENT_SIZE)
    else
        memset(@this.DeferMoveComponentList[0], 0, this.DeferMoveComponentList.Count)
        this.DeferMoveComponentList.Count = 0
    end if
    
    if this.DeferDeleteArchetypeList.Count > this.MIN_DEFER_DELETE_ARCHETYPE_COUNT then
        this.DeferDeleteArchetypeList.ResizeNoSave(this.MIN_DEFER_DELETE_ARCHETYPE_COUNT)
    else
        memset(@this.DeferDeleteArchetypeList[0], 0, this.DeferDeleteArchetypeList.Count * sizeof(ArchetypeIDType))
        this.DeferDeleteArchetypeList.Count = 0
    end if

	this.DeferredPairComponents.Empty()
    
    if this.DeferDeletePairComponentList.Count > this.MIN_DEFER_DELETE_PAIR_COUNT then
        this.DeferDeletePairComponentList.ResizeNoSave(this.MIN_DEFER_DELETE_PAIR_COUNT)
    else
        memset(@this.DeferDeletePairComponentList[0], 0, this.DeferDeletePairComponentList.Count * sizeof(ComponentIDType))
        this.DeferDeletePairComponentList.Count = 0
    end if

    this.HasCommands = 0

end sub

end namespace

#endif
