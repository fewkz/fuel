--!strict
-- Note A. For Element and Resource, we should give them a generic Props type,
-- and replace `props: any` with `props: Props`, and have their children be Element<any>.
-- This is blocked until Luau adds support for recursive types of different generics.
-- See https://github.com/Roblox/luau/pull/86

export type Context<T> = { default: T }
type GetContext = <T>(context: Context<T>) -> T
type SetContext = <T>(context: Context<T>, value: T) -> ()
type Cleanup = (() -> ())?
type OnUpdate<Props> = ((Props) -> Cleanup) -> ()

-- Behavior defines how a resource is supposed to behave. It determines what the resource does when
-- it is created, updated, or destroys. It also allows the resource to access and manipulate context.
type Behavior<Props> = (onUpdate: OnUpdate<Props>, treeOperations: TreeOperations) -> Cleanup

-- Element represents the desired state of a resource at any given point in time.
-- See Note A
export type Element = { behavior: Behavior<any>, props: any, children: { Element } }

type ResourceOperations<Props> = { update: (new: Props, old: Props?) -> ()?, destroy: () -> () }

-- Resources represents an object that can be created, updated, and destroyed.
-- Resources store the props and children that were used to create the resource.
-- The props and children used to create the resource are important so that we can check
-- if any of the configuration changed to determine whether the resource should be updated.
-- See Note A
type Resource = {
	behavior: Behavior<any>,
	props: any,
	operations: ResourceOperations<any>,
	treeContext: TreeContext,
}

-- TreeContext represents data about the resource's position in the tree and the context it's providing.
type TreeContext = {
	parent: Resource?,
	children: { Resource },
	providing: { [Context<any>]: any }, -- The type of the value should match the context's type
	subscriptions: { [Context<any>]: (any) -> () }, -- The type of the parameter should match the context's type
}

-- TreeOperations are provided to a resource to let it interact with context.
export type TreeOperations = {
	-- getContext seeks up the tree to find any resource that's providing the desired context.
	getContext: <T>(context: Context<T>) -> T,
	-- subscribeContext gets the current context and also subscribes to any changes to that
	-- context by marking itself as subscribed to the context.
	subscribeContext: <T>(context: Context<T>, (T) -> ()) -> (() -> ()),
	-- setContext propogates a value down the tree to any resource that is subscribed
	-- to that context. It also marks itself as providing the context for getContext to use.
	setContext: <T>(context: Context<T>, value: T) -> (),
	-- unsetContext is a mixture of getContext and setContext, where it gets context
	-- and then propogates that context down the tree via setContext. It also unmarks
	-- itself as providing the context.
	unsetContext: (context: Context<any>) -> (),
}

-- This uses behavior to generate resource operations that can be used to update and destroy the resource.
local function constructResourceOperations<T>(
	behavior: Behavior<T>,
	props: T,
	treeOperations: TreeOperations
): ResourceOperations<T>
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
	local cleanup = behavior(onUpdate, treeOperations)
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
local function propogateContext<T>(resources: { Resource }, context: Context<T>, value: T)
	for _, resource in resources do
		if resource.treeContext.subscriptions[context] then
			resource.treeContext.subscriptions[context](value)
		end
		-- Don't propogate to context to descendants of a resource
		-- that's providing the same context.
		if resource.treeContext.providing[context] then
			continue
		end
		propogateContext(resource.treeContext.children, context, value)
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

-- Destroys a resource and it's descendants recursively.
local function destroyRecursive(resource: Resource)
	for _, child in resource.treeContext.children do
		destroyRecursive(child)
	end
	resource.operations.destroy()
end

-- Apply takes an array of resources and an array of elements and mutates the resources to match the array of elements.
local function apply(resources: { Resource }, elements: { Element }, parent: Resource?)
	-- Remove resources that no longer exist.
	for i, resource in resources do
		if not elements[i] then
			destroyRecursive(resource)
			resources[i] = nil
		end
	end

	-- Creates new resources or updates existing resources.
	for i, element in elements do
		local existing: Resource? = resources[i]
		local resource: Resource
		if existing then
			resource = existing
		end
		-- Update an existing resource if it's props changed.
		if existing and existing.behavior == element.behavior and existing.props ~= element.props then
			if existing.operations.update then -- if onUpdate() is never called, update will be nil.
				existing.operations.update(element.props)
			end
			existing.props = element.props
		-- Create the resource if it doesn't exist or recreate the resource it's behavior changed.
		elseif not existing or existing.behavior ~= element.behavior then
			if existing then
				-- Unset all of the contexts that the existing resource was providing.
				local operations = makeTreeOperations(existing.treeContext)
				for context in existing.treeContext.providing do
					operations.unsetContext(context)
				end
				-- Destroy the resource via it's defined destroy method.
				existing.operations.destroy()
			end
			local treeContext = {
				parent = parent,
				children = if existing then existing.treeContext.children else {},
				providing = {},
				subscriptions = {},
			}
			local operations =
				constructResourceOperations(element.behavior, element.props, makeTreeOperations(treeContext))
			if existing then
				existing.behavior = element.behavior
				existing.props = element.props
				existing.operations = operations
				existing.treeContext = treeContext
			else
				resource = {
					behavior = element.behavior,
					props = element.props,
					operations = operations,
					treeContext = treeContext,
				}
			end
		end
		apply(resource.treeContext.children, element.children, resource)
		resources[i] = resource
	end
end

local FuelCore = {}

function FuelCore.handle()
	local resources = {}
	return {
		apply = function(elements: { Element })
			apply(resources, elements)
		end,
	}
end

--- Creates a function that can be used to create an element with the given behavior.
function FuelCore.define<Props>(behavior: Behavior<Props>)
	return function(props: Props, children: { Element }?): Element
		return {
			props = props,
			children = if children then children else {},
			behavior = behavior,
		}
	end
end

local ProviderBehavior: Behavior<{ context: Context<any>, value: any }> = function(onUpdate, treeOperations)
	local lastContext, lastValue
	onUpdate(function(props)
		if lastContext ~= props.context or lastValue ~= props.value then
			lastContext, lastValue = props.context, props.value
			treeOperations.setContext(props.context, props.value)
		end
		return
	end)
	return
end

--- Creates a context provider element. Providers provide the given context with the given value to all of it's descendants.
function FuelCore.Provider<T>(props: { context: Context<T>, value: T }, children: { Element }?): Element
	return {
		props = props,
		children = if children then children else {},
		behavior = ProviderBehavior,
	}
end

return FuelCore
