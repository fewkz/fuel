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
type Constructor<Props> = (onUpdate: OnUpdate<Props>, treeOperations: TreeOperations) -> Cleanup

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
	operations: ThingOperations<any>,
	treeContext: TreeContext,
}

-- TreeContext represents data about the thing's position in the tree and the context it's providing.
type TreeContext = {
	parent: Thing?,
	children: { Thing },
	providing: { [Context<any>]: any }, -- The type of the value should match the context's type
	subscriptions: { [Context<any>]: (any) -> () }, -- The type of the parameter should match the context's type
}

-- TreeOperations are provided to a thing to let it interact with context.
type TreeOperations = {
	-- getContext seeks up the tree to find anything that's providing the desired context.
	getContext: <T>(context: Context<T>) -> T,
	-- subscribeContext gets the current context and also subscribes to any changes to that
	-- context by marking itself as subscribed to the context.
	subscribeContext: <T>(context: Context<T>, (T) -> ()) -> (() -> ()),
	-- setContext propogates a value down the tree to any thing that is subscribed
	-- to that context. It also marks itself as providing the context for getContext to use.
	setContext: <T>(context: Context<T>, value: T) -> (),
	-- unsetContext is a mixture of getContext and setContext, where it gets context
	-- and then propogates that context down the tree via setContext. It also unmarks
	-- itself as providing the context.
	unsetContext: (context: Context<any>) -> (),
}

-- This constructs a thing and returns it's operations (update and destroy).
local function constructThingOperations<T>(
	constructor: Constructor<T>,
	props: T,
	treeOperations: TreeOperations
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
	local cleanup = constructor(onUpdate, treeOperations)
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

-- propogateContext will go through the tree and tell any descendant that cares about the context
-- what the new value of the context is.
local function propogateContext<T>(things: { Thing }, context: Context<T>, value: T)
	for _, thing in things do
		if thing.treeContext.subscriptions[context] then
			thing.treeContext.subscriptions[context](value)
		end
		-- Don't propogate to context to descendants of a thing
		-- that's providing the same context.
		if thing.treeContext.providing[context] then
			continue
		end
		propogateContext(thing.treeContext.children, context, value)
	end
end

local function makeTreeOperations(treeContext: TreeContext): TreeOperations
	local function getContext<T>(context: Context<T>): T
		local ancestor = treeContext.parent
		while ancestor do
			-- FIXME: This won't work if the provided context value is nil!
			-- Fixing this will require the entries in providing to be like: { value: T }
			if ancestor.treeContext.providing[context] then
				return ancestor.treeContext.providing[context]
			end
			ancestor = ancestor.treeContext.parent
		end
		return context.default
	end
	local function subscribeContext<T>(context: Context<T>, callback: (T) -> ())
		assert(not treeContext.subscriptions[context], "Can't subscribe to the same context twice.")
		local current = getContext(context)
		if current then
			callback(current)
		end
		treeContext.subscriptions[context] = callback
		return function()
			treeContext.subscriptions[context] = nil
		end
	end
	local function setContext<T>(context: Context<T>, value: T)
		treeContext.providing[context] = value
		propogateContext(treeContext.children, context, value)
	end
	local function unsetContext(context: Context<any>)
		treeContext.providing[context] = nil
		local value = getContext(context)
		propogateContext(treeContext.children, context, value)
	end
	return {
		getContext = getContext,
		subscribeContext = subscribeContext,
		setContext = setContext,
		unsetContext = unsetContext,
	}
end

type ContextStackEntry<T> = { context: Context<T>, value: T }
type ContextStack = { ContextStackEntry<any> }

-- Destroys the children of a thing and the thing itself recursively.
local function destroyRecursive(thing: Thing)
	for _, child in thing.treeContext.children do
		destroyRecursive(child) -- luau errors on this line for some reason
	end
	thing.operations.destroy()
end

-- Apply takes an array of things and an array of elements and mutates the things to match the array of elements.
local function apply(things: { Thing }, elements: { Element }, parent: Thing?)
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
		-- Update an existing thing if it's props changed.
		if existing and existing.constructor == element.constructor and existing.props ~= element.props then
			existing.operations.update(element.props, existing.props)
			existing.props = element.props
		-- Create the thing if it doesn't exist or recreate the thing it's constructor changed.
		elseif not existing or existing.constructor ~= element.constructor then
			if existing then
				existing.operations.destroy()
			end
			local treeContext = {
				parent = parent,
				children = if existing then existing.treeContext.children else {},
				providing = {},
				subscriptions = {},
			}
			local operations =
				constructThingOperations(element.constructor, element.props, makeTreeOperations(treeContext))
			if existing then
				existing.props = element.props
				existing.operations = operations
				existing.treeContext = treeContext
			else
				thing = {
					constructor = element.constructor,
					props = element.props,
					operations = operations,
					treeContext = treeContext,
				}
			end
		end
		apply(thing.treeContext.children, element.children, thing)
		things[i] = thing
	end
end

local FuelCore = {}

function FuelCore.handle()
	local things = {}
	return {
		apply = function(elements: { Element })
			apply(things, elements)
		end,
	}
end

function FuelCore.thing<Props>(constructor: Constructor<Props>): CreateElement<Props>
	return function(props, children)
		return {
			props = props,
			children = if children then children else {},
			constructor = constructor,
		}
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

FuelCore.Provider = FuelCore.thing(function<T>(onUpdate, treeOperations)
	local lastContext, lastValue
	onUpdate(function(props: { context: Context<T>, value: T })
		if lastContext ~= props.context or lastValue ~= props.value then
			lastContext, lastValue = props.context, props.value
			treeOperations.setContext(props.context, props.value)
		end
		return
	end)
	return
end)

local function makeHooks(
	pointerRef: { value: number },
	treeOperations: TreeOperations,
	queueRerender,
	rerender
)
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
	function hooks.useContext<T>(context: Context<T>): T
		local contextValue = hooks.useMemo(function()
			return { value = context.default }
		end)
		hooks.useEffect(function()
			return treeOperations.subscribeContext(context, function(value)
				if value ~= contextValue.value then
					contextValue.value = value
					-- Context changing should always trigger a rerender.
					-- For example, Roblox instance components being unmounted
					-- will set parent context to nil before they're destroyed
					-- so that children have a chance to unparent themselves so
					-- they don't get destroyed as well.
					rerender()
				end
			end)
		end, { context })
		return contextValue.value
	end
	return hooks, function()
		for _, cleanup in cleanups do
			cleanup()
		end
	end
end

export type Hooks = typeof(makeHooks(unpack({} :: any)))

function FuelCore.statefulElements<Props>(callback: (hooks: Hooks, props: Props) -> { Element })
	return FuelCore.thing(function(onUpdate, treeOperations)
		local things = {}
		local hooks, cleanupHooks
		local hooksPointer = { value = 0 }
		local lastProps: Props
		local queuedRerender = false
		local function rerender(props: Props)
			lastProps = props
			hooksPointer.value = 0
			queuedRerender = false
			apply(things, callback(hooks, props))
		end
		hooks, cleanupHooks = makeHooks(hooksPointer, treeOperations, function()
			if not queuedRerender then
				task.defer(rerender, lastProps)
			end
			queuedRerender = true
		end, function()
			rerender(lastProps)
		end)
		onUpdate(rerender)
		return function()
			cleanupHooks()
			apply(things, {})
		end
	end)
end

function FuelCore.statefulElement<Props>(callback: (hooks: Hooks, props: Props) -> Element)
	return FuelCore.statefulElements(function(hooks, props: Props)
		return { callback(hooks, props) }
	end)
end

return FuelCore
