#ifndef FBECS_bi
#define FBECS_bi

#include once "../utilities/AutoHooks.bi"

#include once "../utilities/Vector2I32.bi"
#include once "../utilities/Hash.bi"
#include once "../utilities/BitArray.bi"
#include once "../utilities/DynamicArray.bi"
#include once "../utilities/DynamicArrayListComprehension.bi"

'0 (no logging) to 3 (max logging)
#define ECS_LOG_LEVEL 2

'Define to have all ECS logs saved to a file "ECS_log.txt"
'#define ECS_LOG_TO_FILE

'Convenience macros to reduce boilerplate code
#include once "ECSAPIMacros.bi"

#include once "Logging.bi"
#include once "Entity.bi"
#include once "Component.bi"
#include once "Archetype.bi"
#include once "QueryIterator.bi"
#include once "QuickView.bi"
#include once "System.bi"
#include once "ECSEvents.bi"
#include once "CommandBuffer.bi"
#include once "ECSInstance.bi"

#endif
