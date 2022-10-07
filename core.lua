--!strict

type Context<T> = { default: T }
type GetContext = <T>(context: Context<T>) -> T
type SetContext = <T>(context: Context<T>, value: T) -> ()
type Cleanup = (() -> ())?
type OnUpdate<Props> = ((Props) -> Cleanup) -> ()

-- Constructor is the function used to create a thing. This acts as the classes/types in fuel.
type Constructor<Props> = (onUpdate: OnUpdate<Props>, getContext: GetContext, setContext: SetContext) -> Cleanup

-- A thing represents an object that can be created, updated, and destroyed.
type Thing<Props> = { update: OnUpdate<Props>, destroy: () -> () }

-- Element represents the desired state of a thing at any given point in time.
-- We should replace `props: any` with `props: T` when Luau adds support for recursive types of different generics.
-- See https://github.com/Roblox/luau/pull/86
type Element = { constructor: Constructor<any>, props: any, children: { Element } }

-- RenderedElements represent a tree of things and what they were rendered from.
type RenderedElement = {
	constructor: Constructor<any>,
	props: any,
	thing: Thing<any>,
	children: { RenderedElement },
	getContext: GetContext,
}

local function constructThing<T>(
	constructor: Constructor<T>,
	props: T,
	getContext: GetContext,
	setContext: SetContext
): Thing<T>
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
-- Render takes an existing handle and matches it to the desired state passed in as an element.
-- It returns a handle that represents all of the objects that were created that represent the element.
-- Render transforms an existing handle into a whole new tree of elements.
-- IDEA: we should change existing to an array of RenderedElements. Because the case where existing is nil only happens once.
-- It doesn't make sense for us to have a special case for something that only happens once.
local function render(existing: RenderedElement?, element: Element, parentGetContext: GetContext): RenderedElement
	local getContext: GetContext
	local children = {}
	local handle
	-- If there's an existing handle, based on whether an existing handle was
	-- passed in, and the element's constructor did not change, we will just update the
	-- existing handle.
	if existing and existing.constructor == element.constructor then
		if existing.props ~= element.props then
			existing.thing.update(element.props)
		end
		getContext = existing.getContext
		existing.children = children
		handle = existing
	-- If the element didn't exist, or has a different constructor, we will destroy the
	-- old handle and create a new one.
	else
		if existing then
			existing.thing.destroy()
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
		local thing = constructThing(element.constructor, element.props, getContext, setContext)
		handle = {
			constructor = element.constructor,
			props = element.props,
			thing = thing,
			children = children,
			getContext = getContext,
		}
	end
	-- Remove children that no longer exist
	if existing then
		for i, child in existing.children do
			if not element.children[i] then
				child.thing.destroy()
				existing.children[i] = nil
			end
		end
	end
	-- Update children
	for i, child in element.children do
		children[i] = render(if existing then existing.children[i] else nil, child, getContext)
	end
	return handle
end

local FuelCore = {}

function FuelCore.mount(element: Element)
	return render(nil, element, function(context)
		return context.default
	end)
end

function FuelCore.update(existing: RenderedElement, element: Element)
	return render(existing, element, function(context)
		return context.default
	end)
end

function FuelCore.component<T>(constructor: Constructor<T>): (T, children: { Element }) -> Element
	return function(props, children)
		return { props = props, children = children, constructor = constructor }
	end
end

return FuelCore
