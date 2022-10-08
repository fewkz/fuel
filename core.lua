--!strict
-- Note A. For Element and Thing, we should give them a generic Props type,
-- and replace `props: any` with `props: Props`, and have their children be Element<any>.
-- This is blocked until Luau adds support for recursive types of different generics.
-- See https://github.com/Roblox/luau/pull/86

type Context<T> = { default: T }
type GetContext = <T>(context: Context<T>) -> T
type SetContext = <T>(context: Context<T>, value: T) -> ()
type Cleanup = (() -> ())?
type OnUpdate<Props> = ((new: Props, old: Props?) -> Cleanup) -> ()

-- Constructor is the function used to create a thing. This acts as the classes/types in fuel.
type Constructor<Props> = (onUpdate: OnUpdate<Props>, getContext: GetContext, setContext: SetContext) -> Cleanup

-- Element represents the desired state of a thing at any given point in time.
-- See Note A
type Element = { constructor: Constructor<any>, props: any, children: { Element } }

-- CreateElement is a function that takes props and children and returns an element.
type CreateElement<Props> = (Props, children: { Element }?) -> Element

type ThingOperations<Props> = { update: (new: Props, old: Props?) -> (), destroy: () -> () }

-- A thing represents an object that can be created, updated, and destroyed.
-- Things store the props and children that were used to create the thing.
-- The props and children used to create the thing is important so that we can check if any of the
-- configuration changed to determine whether the thing should be updated.
-- I need a better name for this, or I could just store the props and children in Thing itself.
-- See Note A
type Thing = {
	constructor: Constructor<any>,
	props: any,
	children: { Thing },
	operations: ThingOperations<any>,
	getContext: GetContext,
}

local function constructThingOperations<T>(
	constructor: Constructor<T>,
	props: T,
	getContext: GetContext,
	setContext: SetContext
): ThingOperations<T>
	local update, cleanupLastUpdate = nil, nil
	local onUpdate: OnUpdate<any> = function(callback)
		assert(update == nil, "onUpdate can only be called once!")
		cleanupLastUpdate = callback(props)
		update = function(props)
			if cleanupLastUpdate then
				cleanupLastUpdate()
			end
			cleanupLastUpdate = callback(props)
		end
	end
	local cleanup = constructor(onUpdate, getContext, setContext)
	local destroy = function()
		if cleanupLastUpdate then
			cleanupLastUpdate()
		end
		if cleanup then
			cleanup()
		end
	end
	return { update = update, destroy = destroy }
end

type ContextStackEntry<T> = { context: Context<T>, value: T }
type ContextStack = { ContextStackEntry<any> }

-- Destroys the children of a thing and the thing itself recursively.
local function destroyRecursive(thing: Thing)
	for _, child in thing.children do
		destroyRecursive(child) -- luau errors on this line for some reason
	end
	thing.operations.destroy()
end

-- Apply takes an array of things and an array of elements and mutates the things to match the array of elements.
local function apply(things: { Thing }, elements: { Element }, parentGetContext: GetContext)
	local getContext: GetContext
	-- Remove things that no longer exist.
	for i, thing in things do
		if not elements[i] then
			destroyRecursive(thing)
			things[i] = nil
		end
	end

	-- Creates new things or updates existing things.
	for i, element in elements do
		local existing: Thing? = things[i]
		local thing: Thing
		if existing then
			thing = existing
		end
		if existing and existing.constructor == element.constructor and existing.props ~= element.props then
			existing.operations.update(element.props, existing.props)
			existing.props = element.props
			getContext = existing.getContext
		end
		if not existing or existing.constructor ~= element.constructor then
			if existing then
				existing.operations.destroy()
			end
			local localContext: any = {}
			getContext = function(context)
				if localContext[context] then
					return localContext[context]
				else
					return parentGetContext(context)
				end
			end
			local setContext: SetContext = function(context, value)
				localContext[context] = value
			end
			local operations = constructThingOperations(element.constructor, element.props, getContext, setContext)
			if existing then
				thing.operations = operations
			else
				thing = {
					constructor = element.constructor,
					props = element.props,
					children = {},
					operations = operations,
					getContext = getContext,
				}
			end
		end
		apply(thing.children, element.children, getContext)
		things[i] = thing
	end
end

local function defaultGetContext(context)
	return context.default
end

local FuelCore = {}

function FuelCore.handle()
	local things = {}
	return {
		apply = function(elements: { Element })
			apply(things, elements, defaultGetContext)
		end,
	}
end

function FuelCore.thing<Props>(constructor: Constructor<Props>): CreateElement<Props>
	return function(props, children)
		return { props = props, children = if children then children else {}, constructor = constructor }
	end
end

local function dependenciesChanged(old: { any }, new: { any })
	if old == new then
		return false
	end
	if #old ~= #new then
		return true
	end
	for i in old do
		if new[i] == nil or new[i] ~= old[i] then
			return true
		end
	end
	return false
end

local function makeHooks(pointerRef: { value: number }, queueRerender)
	local state: any = {}
	local hooks = {}
	function hooks.useState<T>(initial: T): (T, (T | (T) -> T) -> ())
		pointerRef.value += 1
		local pointer = pointerRef.value
		assert(
			state[pointer] == nil or typeof(state[pointer]) == typeof(initial),
			"useState failed because internal hook state was corrupted. Please consult the rules of hooks."
		)
		local currentState = if state[pointer] then state[pointer] else initial
		return currentState,
			function(change)
				if typeof(change) == "function" then
					state[pointer] = change(currentState)
				else
					state[pointer] = change
				end
				queueRerender()
			end
	end
	local cleanups: { () -> () } = {}
	function hooks.useEffect(callback: () -> (() -> ())?, dependencies: { any })
		pointerRef.value += 1
		local pointer = pointerRef.value
		local lastDependencies = state[pointer]
		assert(
			lastDependencies == nil or typeof(lastDependencies) == "table",
			"useEffect failed because internal hook state was corrupted. Please consult the rules of hooks."
		)
		if lastDependencies ~= nil and not dependenciesChanged(lastDependencies, dependencies) then
			return
		end
		if cleanups[pointer] then
			cleanups[pointer]()
		end
		local cleanup = callback()
		if cleanup then
			cleanups[pointer] = cleanup
		end
		state[pointer] = dependencies
	end
	function hooks.useMemo<T>(callback: () -> (T)): T
		pointerRef.value += 1
		local pointer = pointerRef.value
		if not state[pointer] then
			state[pointer] = { value = callback() }
		end
		assert(
			typeof(state[pointer]) == "table",
			"useMemo failed because internal hook state was corrupted. Please consult the rules of hooks."
		)
		return state[pointer].value
	end
	return hooks, function()
		for _, cleanup in cleanups do
			cleanup()
		end
	end
end

type Hooks = typeof(makeHooks({ value = 0 }, function() end))

function FuelCore.statefulElements<Props>(callback: (hooks: Hooks, props: Props) -> { Element })
	return FuelCore.thing(function(onUpdate, getContext, setContext)
		local things = {}
		local hooks, cleanupHooks
		local hooksPointer = { value = 0 }
		local lastProps: Props
		local queuedRerender = false
		local function rerender(props: Props)
			lastProps = props
			hooksPointer.value = 0
			queuedRerender = false
			apply(things, callback(hooks, props), getContext)
		end
		hooks, cleanupHooks = makeHooks(hooksPointer, function()
			if not queuedRerender then
				task.defer(rerender, lastProps)
			end
			queuedRerender = true
		end)
		onUpdate(rerender)
		return function()
			cleanupHooks()
			apply(things, {}, getContext)
		end
	end)
end

function FuelCore.statefulElement<Props>(callback: (hooks: Hooks, props: Props) -> Element)
	return FuelCore.statefulElements(function(hooks, props: Props)
		return { callback(hooks, props) }
	end)
end

return FuelCore
