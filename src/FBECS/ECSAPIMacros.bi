#ifndef ECSAPIMacros_bi
#define ECSAPIMacros_bi

/''

    API CONTENTS CHEAT SHEET
    See implementations below for more details
    ''''''''''''''''''''''''''''''''''''''''''Interacting with components and events''''''''''''''''''''''''''''''''''''''''''
    
    ECS_ADD_COMPONENT(_INSTANCE, _ENTITYID, _COMPONENT)
    ECS_ADD_COMPONENT_W_VALUE(_INSTANCE, _ENTITYID, _COMPONENT, _VALUE)
    
    ECS_ENQUEUE_EVENT(_INSTANCE, _EVENT)
    ECS_ENQUEUE_EVENT_W_VALUE(_INSTANCE, _EVENT, _VALUE)
    
    ECS_ADD_CHILDOF(_INSTANCE, _CHILDID, _PARENTID)
    
    ECS_REMOVE_COMPONENT(_INSTANCE, _ENTITYID, _COMPONENT)
    
    ECS_GET_SINGLETON(_INSTANCE, _COMPONENT)
    ECS_GET_COMPONENT(_INSTANCE, _ENTITYID, _COMPONENT)

    ECS_FOR_EACH_QUICKVIEW
    ECS_FOR_EACH_ITERATOR
    ECS_FOR_EACH(_VARIABLE, _COMPONENTID, _INSTANCE)
	ECS_FOR_EACH_TYPE_OVERRIDE(_VARIABLE, _TYPE, _COMPONENTID, _INSTANCE)
    ECS_FOR_EACH_NEXT
    
    ''''''''''''''''''''''''''''''''''''''''''System/event handler setup''''''''''''''''''''''''''''''''''''''''''
    
    ECS_SYSTEM_CALLBACK(_SYSTEM_NAME)
    ECS_SYSTEM_SIGNATURE(_SYSTEM_NAME)
    ECS_DECLARE_SYSTEM(_SYSTEM_NAME)
    
    ECS_EVENT_HANDLER_CALLBACK(_EVENT_HANDLER_NAME)
    ECS_EVENT_HANDLER_SIGNATURE(_EVENT_HANDLER_NAME)
    ECS_DECLARE_EVENT_HANDLER(_EVENT_HANDLER_NAME)
    
    ECS_ADD_UNBOUNDED_SYSTEM(_INSTANCE, _SYSTEM, _CALLBACK, _COMPONENTS...)
    ECS_ADD_TICK_SYSTEM(_INSTANCE, _SYSTEM, _CALLBACK, _COMPONENTS...)
    ECS_ADD_EVENT_HANDLER_SYSTEM(_INSTANCE, _EVENT, _CALLBACK)
    
    '''''''''''''''''''''''''''''''''''''''''Component and event Type setup'''''''''''''''''''''''''''''''''''''''''
    
    ECS_TYPE(_COMPONENT)
    
	ECS_DECLARE_COMPONENT(_COMPONENT)
    ECS_DEFINE_COMPONENT(_COMPONENT)
    ECS_DECLARE_EVENT(_COMPONENT)
    ECS_DEFINE_EVENT(_COMPONENT)
    
    ECS_REGISTER_SINGLETON(_INSTANCE, _COMPONENT)
    ECS_REGISTER_COMPONENT(_INSTANCE, _COMPONENT)
	ECS_REGISTER_PAIR(_INSTANCE, _OUT_COMPONENT, _BASE, _TARGET, _COMPONENT_TYPE)
    ECS_REGISTER_EVENT(_INSTANCE, _EVENT)
	
	'''''''''''''''''''''''''''''''''''''''''Module setup'''''''''''''''''''''''''''''''''''''''''
	
	ECS_MODULE_CALLBACK(_MODULE_NAME)
	ECS_MODULE_SIGNATURE(_MODULE_NAME)
	ECS_DECLARE_MODULE(_MODULE_NAME)
	ECS_IMPORT_MODULE(_INSTANCE, _MODULE_NAME)
	
''/

'''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''''
/'''''''''''''''''''''''''''''''''''''''''INTERNAL USE'''''''''''''''''''''''''''''''''''''''''/

'These macros are used to get __VA_ARGS__ count
'This also allows a soft enforcement of type safety
'as the compiler will throw a warning for suspicious pointer assignment
#macro _COMPONENT_VA_ARG_COUNT_START(_ARGS...)
scope
#if #_ARGS = ""
redim _arg_array_(-1) as FBECS.QueryTermType
#else
dim _arg_array_(...) as FBECS.QueryTermType = {_ARGS}
#endif
#endmacro

#macro _COMPONENT_VA_ARG_COUNT_GET()
(ubound(_arg_array_)+1)
#endmacro

#macro _COMPONENT_VA_ARG_COUNT_END(ARGS...)
end scope
#endmacro

/'''''''''''''''''''''''''''''''''''''''''Interacting with the components and events''''''''''''''''''''''''''''''''''''''''''/

'Convenience macro to add a component to an entity
' - _INSTANCE : FBECS.ECSInstanceType
' - _ENTITYID : FBECS.EntityIDType
' - _COMPONENT: registered FBECS.ComponentIDType
#macro ECS_ADD_COMPONENT(_INSTANCE, _ENTITYID, _COMPONENT)
#if NOT defined(_COMPONENT)
	#error "Component not declared: " _COMPONENT
#endif
(_INSTANCE).AddComponent((_ENTITYID), (_COMPONENT))
#endmacro

'Convenience macro to add a component with a value to an entity
' - _INSTANCE : FBECS.ECSInstanceType
' - _ENTITYID : FBECS.EntityIDType
' - _COMPONENT: registered FBECS.ComponentIDType
' - _VALUE    : user defined component with values (e.g. Vector2D(1.0, 2.0))
#macro ECS_ADD_COMPONENT_W_VALUE(_INSTANCE, _ENTITYID, _COMPONENT, _VALUE)
(_INSTANCE).AddComponent((_ENTITYID), (_COMPONENT), sizeof(typeof(_VALUE)), cast(typeof(_VALUE) ptr, @(_VALUE)))
#endmacro

'Convenience macro to add an event (with 0 size)
' - _INSTANCE : FBECS.ECSInstanceType
' - _EVENT    : FBECS.EventIDType
#macro ECS_ENQUEUE_EVENT(_INSTANCE, _EVENT)
(_INSTANCE).EnqueueEvent((_EVENT))
#endmacro

'Convenience macro to add an event with a value
' - _INSTANCE : FBECS.ECSInstanceType
' - _EVENT    : FBECS.EventIDType
' - _VALUE    : user defined event type with values (e.g. Vector2D(1.0, 2.0))
#macro ECS_ENQUEUE_EVENT_W_VALUE(_INSTANCE, _EVENT, _VALUE)
(_INSTANCE).EnqueueEvent((_EVENT), @(_VALUE))
#endmacro

'Sets an entity _CHILDID to be a child of entity _PARENTID
' - _INSTANCE : FBECS.ECSInstanceType
' - _CHILDID  : FBECS.EntityIDType (entity to become a child)
' - _PARENTID : FBECS.EntityIDType (entity to become the parent)
#macro ECS_ADD_CHILDOF(_INSTANCE, _CHILDID, _PARENTID)
(_INSTANCE).AddChildOf((_CHILDID), (_PARENTID))
#endmacro

'Does what it says on the tin
#macro ECS_REMOVE_COMPONENT(_INSTANCE, _ENTITYID, _COMPONENT)
(_INSTANCE).RemoveComponent((_ENTITYID), (_COMPONENT))
#endmacro

'Gets a pointer to a registered singleton
'Best used with 'var' variable assignment
' - _INSTANCE  : FBECS.ECSInstanceType
' - _COMPONENT : registered singleton FBECS.ComponentIDType
#macro ECS_GET_SINGLETON(_INSTANCE, _COMPONENT)
cast(typeof(ECS_TYPE(_COMPONENT)) ptr, (_INSTANCE).GetSingletonComponent(_COMPONENT))
#endmacro

'Gets a pointer to a component on an entity if it exists
'Best used with 'var' variable assignment
' - _INSTANCE  : FBECS.ECSInstanceType
' - _ENTITYID  : FBECS.EntityIDType
' - _COMPONENT : registered component FBECS.ComponentIDType
#macro ECS_GET_COMPONENT(_INSTANCE, _ENTITYID, _COMPONENT)
cast(typeof(ECS_TYPE(_COMPONENT)) ptr, (_INSTANCE).GetComponent(_ENTITYID, _COMPONENT))
#endmacro

'Allows the user to access the quickview created
'by the ECS_FOR_EACH macro
#define ECS_FOR_EACH_QUICKVIEW _forEachQuickView

'Allows the user to access the iterator created
'by the ECS_FOR_EACH macro
#define ECS_FOR_EACH_ITERATOR _forEachIterator

'Creates the same behavior as an "exit for" would for iteration purposes
'to be used with the ECS_FOR_EACH macro
'Requires passing in the ECS instance
#macro ECS_FOR_EACH_EXIT
:ECS_FOR_EACH_QUICKVIEW.Terminate():exit while:
#endmacro

'Creates the same behavior as an "continue for" would for iteration purposes
'to be used with the ECS_FOR_EACH macro
#define ECS_FOR_EACH_CONTINUE :continue for:

'Allows easy of use for iterating over single components
'Creates a quick view and iterates over it.
'Use in conjunction with the ECS_FOR_EACH_NEXT macro
' - _VARIABLE: The output variable for each component value (may be blank if iterating over tags)
' - _COMPONENT_ID: The proper name of a declared component of type FBECS.ComponentIDType
' - _INSTANCE: An FBECS.ECSInstance
#macro ECS_FOR_EACH(_VARIABLE, _COMPONENTID, _INSTANCE)
#if typeof(_COMPONENTID) <> typeof(FBECS.ComponentIDType)
#error Type mismatch, at parameter 2 ##_COMPONENT: expected FBECS.ComponentIDType
#endif
#if typeof(_INSTANCE) <> typeof(FBECS.ECSInstanceType)
#error Type mismatch, at parameter 3 ##_INSTANCE: expected FBECS.ECSInstanceType
#endif
scope
	dim ECS_FOR_EACH_QUICKVIEW as FBECS.QuickViewType
	ECS_FOR_EACH_QUICKVIEW.QueriedComponent = _COMPONENTID
	if (_INSTANCE).PrepareQuery(ECS_FOR_EACH_QUICKVIEW) <> 0 then
		while (_INSTANCE).QueryNext(ECS_FOR_EACH_QUICKVIEW)
			#if defined(_COMPONENTID##Type) ANDALSO sizeof(ECS_TYPE(_COMPONENTID)) <> 0
			dim _forEachVariable as ECS_TYPE(_COMPONENTID) ptr = ECS_FOR_EACH_QUICKVIEW.GetArgumentArray()
			#endif
			for ECS_FOR_EACH_ITERATOR as integer = 0 to ECS_FOR_EACH_QUICKVIEW.NodeCount - 1
				#if defined(_COMPONENTID##Type) ANDALSO sizeof(ECS_TYPE(_COMPONENTID)) <> 0
				var byref _VARIABLE = _forEachVariable[ECS_FOR_EACH_ITERATOR]
				#endif
#endmacro

'Same as ECS_FOR_EACH but this explicitly specifies a type for the variable
'This should be used with pairs that have types
'Use in conjunction with the ECS_FOR_EACH_NEXT macro
' - _VARIABLE: The output variable for each component value (may be blank if iterating over tags)
' - _COMPONENT_TYPE: The component with an associated type that the _COMPONENTID should have
' - _COMPONENT_ID: The proper name of a declared component of type FBECS.ComponentIDType
' - _INSTANCE: An FBECS.ECSInstance
#macro ECS_FOR_EACH_TYPE_OVERRIDE(_VARIABLE, _COMPONENT_TYPE, _COMPONENTID, _INSTANCE)
#if typeof(_COMPONENTID) <> typeof(FBECS.ComponentIDType)
#error Type mismatch, at parameter 3 ##_COMPONENT: expected FBECS.ComponentIDType
#endif
#if typeof(_INSTANCE) <> typeof(FBECS.ECSInstanceType)
#error Type mismatch, at parameter 4 ##_INSTANCE: expected FBECS.ECSInstanceType
#endif
#if (NOT defined(_COMPONENT_TYPE##Type)) ORELSE sizeof(ECS_TYPE(_COMPONENTID)) = 0
#error ##_COMPONENT_TYPE does not have an associated type?
#endif
scope
	dim ECS_FOR_EACH_QUICKVIEW as FBECS.QuickViewType
	ECS_FOR_EACH_QUICKVIEW.QueriedComponent = _COMPONENTID
	if (_INSTANCE).PrepareQuery(ECS_FOR_EACH_QUICKVIEW) <> 0 then
		while (_INSTANCE).QueryNext(ECS_FOR_EACH_QUICKVIEW)
			dim _forEachVariable as ECS_TYPE(_COMPONENT_TYPE) ptr = ECS_FOR_EACH_QUICKVIEW.GetArgumentArray()
			for ECS_FOR_EACH_ITERATOR as integer = 0 to ECS_FOR_EACH_QUICKVIEW.NodeCount - 1
				var byref _VARIABLE = _forEachVariable[ECS_FOR_EACH_ITERATOR]
#endmacro

'The second half of the ECS_FOR_EACH_MACRO
#macro ECS_FOR_EACH_NEXT
		:next:wend: _
	end if:

end scope:
#endmacro

/''''''''''''''''''''''''''''''''''''''''''System/event handler setup''''''''''''''''''''''''''''''''''''''''''/

'Generates a system's callback name
#macro ECS_SYSTEM_CALLBACK(_SYSTEM_NAME)
##_SYSTEM_NAME##_ECS_SYSTEM_CALLBACK
#endmacro

'Generate the system signature.  Used to implement the system callback
#macro ECS_SYSTEM_SIGNATURE(_SYSTEM_NAME)
ECS_SYSTEM_CALLBACK(_SYSTEM_NAME)(FBECS_SYSTEM_CALLBACK_PARAMETERS)
#endmacro

'Forward declares a system with callback
#macro ECS_DECLARE_SYSTEM(_SYSTEM_NAME)
dim shared as FBECS.SystemType ##_SYSTEM_NAME
declare sub ECS_SYSTEM_SIGNATURE(_SYSTEM_NAME)
#endmacro

'Generates an event handler callback
'Note that this does NOT need the name of an event
#macro ECS_EVENT_HANDLER_CALLBACK(_EVENT_HANDLER_NAME)
##_EVENT_HANDLER_NAME##_ECS_EVENT_HANDLER_CALLBACK
#endmacro

'Generates an event callback signature.  Used to implement the event callback
#macro ECS_EVENT_HANDLER_SIGNATURE(_EVENT_HANDLER_NAME)
ECS_EVENT_HANDLER_CALLBACK(_EVENT_HANDLER_NAME)(FBECS_EVENT_CALLBACK_SIGNATURE)
#endmacro

'Forward declares an event handler callback
#macro ECS_DECLARE_EVENT_HANDLER(_EVENT_HANDLER_NAME)
declare sub ECS_EVENT_HANDLER_SIGNATURE(_EVENT_HANDLER_NAME)
#endmacro

'Add an unbounded system with a defined query
' - _INSTANCE      : FBECS.ECSInstanceType
' - _PHASE         : FBECS.PhaseEnum (optional, leave blank for default UPDATE_PHASE)
' - _SYSTEM        : out FBECS.SystemType
' - _COMPONENTS... : Comma seperated list of ComponentIDType ptrs
#macro ECS_ADD_UNBOUNDED_SYSTEM(_INSTANCE, _PHASE, _SYSTEM, _COMPONENTS...)
#define _CALLBACK ECS_SYSTEM_CALLBACK(_SYSTEM)
#if typeof(_SYSTEM) <> typeof(FBECS.SystemType)
	#error "System was not declared before adding: " _SYSTEM
#endif
scope
if (_SYSTEM).Callback <> 0 then
    LogError("System was already created: ";#_SYSTEM;!"\n" _
        __FILE__;" near line:";__LINE__;!"\n"; _
        "ECS_ADD_UNBOUNDED_SYSTEM("; _
        #_INSTANCE;", ";#_SYSTEM;", ";#_COMPONENTS;")")
end if
_COMPONENT_VA_ARG_COUNT_START(_COMPONENTS) 'Create the array for the arg count
_SYSTEM = FBECS.SystemType( _ 'Set _SYSTEM to be created
    #_SYSTEM, _
    @_CALLBACK, _ 'Add the callback
    FBECS.QueryType(#_SYSTEM).AddComponents(_arg_array_())) 'Add component list to query
(_INSTANCE).AddUnboundedSystem(@##_SYSTEM, _PHASE) 'Append the system to the sytem list
(_INSTANCE).RegisterCachedQuery(@(_SYSTEM).Query) 'Set the system's query to be cached
_COMPONENT_VA_ARG_COUNT_END() 'Destroy the array for the arg count
end scope
#undef _CALLBACK
#endmacro

'See above for arguments
#macro ECS_ADD_TICK_SYSTEM(_INSTANCE, _PHASE, _SYSTEM, _COMPONENTS...)
#define _CALLBACK @ECS_SYSTEM_CALLBACK(_SYSTEM)
#if typeof(_SYSTEM) <> typeof(FBECS.SystemType)
	#error "System was not declared before adding: " _SYSTEM
#endif
scope
if (_SYSTEM).Callback <> 0 then
    LogError("System was already created: ";#_SYSTEM;!"\n" _
        __FILE__;" near line:";__LINE__;!"\n"; _
        "ECS_ADD_TICK_SYSTEM("; _
        #_INSTANCE;", ";#_SYSTEM;", ";#_COMPONENTS;")")
end if
_COMPONENT_VA_ARG_COUNT_START(_COMPONENTS)
_SYSTEM = FBECS.SystemType( _
    #_SYSTEM, _
    _CALLBACK, _
    FBECS.QueryType(#_SYSTEM).AddComponents(_arg_array_()))
(_INSTANCE).AddTickSystem(@##_SYSTEM, _PHASE)
(_INSTANCE).RegisterCachedQuery(@(_SYSTEM).Query)
_COMPONENT_VA_ARG_COUNT_END()
end scope
#undef _CALLBACK
#endmacro

'Add an event handler system from an EventIDType returned from RegisterEvent()
' - _INSTANCE : FBECS.ECSInstanceType
' - _PHASE    : optional FBECS.PhaseEnum
' - _EVENT    : FBECS.EventIDType
' - _HANDLER  : Name of a declared event handler
#macro ECS_ADD_EVENT_HANDLER_SYSTEM(_INSTANCE, _PHASE, _EVENT, _HANDLER)
#define _CALLBACK @ECS_EVENT_HANDLER_CALLBACK(_HANDLER)
scope
	if (_EVENT) = 0 then
		LogError(!"Event \"";#_EVENT;!"\" was not registered!  "; _
			"Use the ECS_REGISTER_EVENT macro.")
	end if
	(_INSTANCE).AddEventHandlerSystem((#_HANDLER), (_EVENT), (_CALLBACK), _PHASE)
end scope
#undef _CALLBACK
#endmacro

/''''''''''''''''''''''''''''''''''''''''''Component and event Type setup''''''''''''''''''''''''''''''''''''''''''/

'Generates the type name for a component or event
'Note: If the type name ever changes, many of the macros below will have to as well
#macro ECS_TYPE(_COMPONENT)
##_COMPONENT##Type
#endmacro

'Declares a component variable (for use in header)
#macro ECS_DECLARE_COMPONENT(_COMPONENT)
extern _COMPONENT as FBECS.ComponentIDType
'Only declare hooks for types that actually exists (not tags)
#if defined(##_COMPONENT##Type)
DECLARE_HOOKS(ECS_TYPE(_COMPONENT))
#endif
#endmacro

'Defines a component variable (for use in source)
#macro ECS_DEFINE_COMPONENT(_COMPONENT)
dim shared as FBECS.ComponentIDType _COMPONENT
#if defined(##_COMPONENT##Type)
GENERATE_HOOKS(ECS_TYPE(_COMPONENT))
#endif
#endmacro

'Declares an event variable (for use in header)
#macro ECS_DECLARE_EVENT(_EVENT)
extern _EVENT as FBECS.EventIDType
#if defined(##_EVENT##Type)
DECLARE_HOOKS(ECS_TYPE(_EVENT))
#endif
#endmacro

'Defines an event variable (for use in source)
#macro ECS_DEFINE_EVENT(_EVENT)
dim shared as FBECS.EventIDType _EVENT
#if defined(##_EVENT##Type)
GENERATE_HOOKS(ECS_TYPE(_EVENT))
#endif
#endmacro

'Convenience for registering a singleton component
#macro ECS_REGISTER_SINGLETON(_INSTANCE, _COMPONENT)
#ifndef ##_COMPONENT
	#error "Singleton was not declared before registering: " _COMPONENT
#endif
#if typeof(_COMPONENT) <> typeof(FBECS.ComponentIDType)
	#error "Cannot register a singleton that is not of type FBECS.ComponentIDType " _COMPONENT
#endif
'Generate the various arguments
scope
#ifdef ##_COMPONENT##Type
	dim _hookID as uinteger<32> = GET_AUTO_HOOK_TYPE_ID(ECS_TYPE(_COMPONENT))
	if _hookID = 0 then
		LogError("Component: ";#_COMPONENT;!" does not have auto hooks generated, possible typedef?\n" & _
			"You must manually GENERATE_HOOKS(...) for the base type.")
	end if
	#define _TYPE_SIZE (sizeof(ECS_TYPE(_COMPONENT)))
	#define _TYPE_CTOR AutoHooks.Construct(_hookID)
	#define _TYPE_DTOR AutoHooks.Destruct(_hookID)
	#define _TYPE_COPY AutoHooks.Copy(_hookID)
	#define _TYPE_MOVE AutoHooks._Swap(_hookID)
#else
	'Component is a tag
	#define _TYPE_SIZE 0
	#define _TYPE_CTOR 0
	#define _TYPE_DTOR 0
	#define _TYPE_COPY 0
	#define _TYPE_MOVE 0
#endif

_COMPONENT = ##_INSTANCE##.RegisterSingletonComponent( _
	_TYPE_SIZE, _
	#_COMPONENT, _
	0, _
	_TYPE_CTOR, _TYPE_DTOR, _TYPE_COPY, _TYPE_MOVE)
end scope

'Cleanup the typedefs
#undef _TYPE_SIZE
#undef _TYPE_CTOR
#undef _TYPE_DTOR
#undef _TYPE_COPY
#undef _TYPE_MOVE
#endmacro

'Convenience macro for registering a component
#macro ECS_REGISTER_COMPONENT(_INSTANCE, _COMPONENT)
#ifndef ##_COMPONENT
	#error "Component was not declared before registering: " _COMPONENT)
#endif
#if typeof(_COMPONENT) <> typeof(FBECS.ComponentIDType)
	#error "Cannot register a component that is not of type FBECS.ComponentIDType " _COMPONENT
#endif
scope
'Generate the various arguments
#ifdef ##_COMPONENT##Type
	dim _hookID as uinteger<32> = GET_AUTO_HOOK_TYPE_ID(ECS_TYPE(_COMPONENT))
	if _hookID = 0 then
		LogError("Component: ";#_COMPONENT;!" does not have auto hooks generated, possible typedef?\n" & _
			"You must manually GENERATE_HOOKS(...) for the base type.")
	end if
	#define _TYPE_SIZE (sizeof(ECS_TYPE(_COMPONENT)))
	#define _TYPE_CTOR AutoHooks.Construct(_hookID)
	#define _TYPE_DTOR AutoHooks.Destruct(_hookID)
	#define _TYPE_COPY AutoHooks.Copy(_hookID)
	#define _TYPE_MOVE AutoHooks._Swap(_hookID)
#else
	'Component is a tag
	#define _TYPE_SIZE 0
	#define _TYPE_CTOR 0
	#define _TYPE_DTOR 0
	#define _TYPE_COPY 0
	#define _TYPE_MOVE 0
#endif

_COMPONENT = ##_INSTANCE##.RegisterComponent( _
	_TYPE_SIZE, _
	#_COMPONENT, _
	_TYPE_CTOR, _TYPE_DTOR, _TYPE_COPY, _TYPE_MOVE)
end scope
'Cleanup the typedefs
#undef _TYPE_SIZE
#undef _TYPE_CTOR
#undef _TYPE_DTOR
#undef _TYPE_COPY
#undef _TYPE_MOVE
#endmacro

#macro ECS_REGISTER_PAIR(_INSTANCE, _OUT_COMPONENT, _BASE, _TARGET, _COMPONENT_TYPE)
#if typeof(_BASE) <> typeof(FBECS.ComponentIDType)
	#error "Cannot register pair with a base component that is not of type FBECS.ComponentIDType " _BASE
#endif
scope
'Generate the various arguments
#if (#_COMPONENT_TYPE <> "") ANDALSO defined(##_COMPONENT_TYPE##Type)
	dim _hookID as uinteger<32> = GET_AUTO_HOOK_TYPE_ID(ECS_TYPE(_COMPONENT_TYPE))
	if _hookID = 0 then
		LogError("Component: ";#_COMPONENT_TYPE;!" does not have auto hooks generated, possible typedef?\n" & _
			"You must manually GENERATE_HOOKS(...) for the base type.")
	end if
	#define _TYPE_SIZE (sizeof(ECS_TYPE(_COMPONENT_TYPE)))
	#define _TYPE_CTOR AutoHooks.Construct(_hookID)
	#define _TYPE_DTOR AutoHooks.Destruct(_hookID)
	#define _TYPE_COPY AutoHooks.Copy(_hookID)
	#define _TYPE_MOVE AutoHooks._Swap(_hookID)
#else
	'Component is a tag
	#define _TYPE_SIZE 0
	#define _TYPE_CTOR 0
	#define _TYPE_DTOR 0
	#define _TYPE_COPY 0
	#define _TYPE_MOVE 0
#endif

_OUT_COMPONENT = ##_INSTANCE##.RegisterPairComponent( _
	_BASE, _
	_TARGET, _
	_TYPE_SIZE, _
	_TYPE_CTOR, _TYPE_DTOR, _TYPE_COPY, _TYPE_MOVE)
end scope
'Cleanup the typedefs
#undef _TYPE_SIZE
#undef _TYPE_CTOR
#undef _TYPE_DTOR
#undef _TYPE_COPY
#undef _TYPE_MOVE
#endmacro

'Convenience macro for registering an event
#macro ECS_REGISTER_EVENT(_INSTANCE, _EVENT)
#ifndef ##_EVENT
	#error "Event was not declared before registering: " _EVENT)
#endif
#if typeof(_EVENT) <> typeof(FBECS.EventIDType)
	#error "Cannot register event that is not of type FBECS.EventIDType " _EVENT
#endif
'Generate the various arguments
scope
#ifdef ##_EVENT##Type
	 dim _hookID as uinteger<32> = GET_AUTO_HOOK_TYPE_ID(ECS_TYPE(_EVENT))
	if _hookID = 0 then
		LogError(!"Event: ";#_EVENT;" does not have auto hooks generated, possible typedef?\n" & _
			"You must manually GENERATE_HOOKS(...) for the base type.")
	end if
	#define _TYPE_SIZE (sizeof(ECS_TYPE(_EVENT)))
	#define _TYPE_DTOR AutoHooks.Destruct(_hookID)
#else
	#define _TYPE_SIZE 0
	#define _TYPE_DTOR 0
#endif

_EVENT = ##_INSTANCE##.RegisterEvent( _
	_TYPE_SIZE, _
	#_EVENT, _
	 _TYPE_DTOR)
end scope
'Cleanup the typedefs
#undef _TYPE_SIZE
#undef _TYPE_DTOR
#endmacro

#macro ECS_MODULE_CALLBACK(_MODULE_NAME)
##_MODULE_NAME##_ECS_MODULE_CALLBACK
#endmacro

#macro ECS_MODULE_SIGNATURE(_MODULE_NAME)
ECS_MODULE_CALLBACK(_MODULE_NAME)(IMPORT_MODULE_PARAMETERS)
#endmacro

#macro ECS_DECLARE_MODULE(_MODULE_NAME)
declare sub ECS_MODULE_SIGNATURE(_MODULE_NAME)
#endmacro

#macro ECS_IMPORT_MODULE(_INSTANCE, _MODULE_NAME)
(_INSTANCE).ImportModule(@ECS_MODULE_CALLBACK(_MODULE_NAME), #_MODULE_NAME)
#endmacro

#endif
