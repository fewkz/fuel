--!strict

type Context<T> = { default: T }
type GetContext = <T>(context: Context<T>) -> T
type SetContext = <T>(context: Context<T>, value: T) -> ()
type Cleanup = (() -> ())?
type OnUpdate<Props> = ((new: Props, old: Props?) -> Cleanup) -> ()

-- Constructor is the function used to create a thing. This acts as the classes/types in fuel.
type Constructor<Props> = (onUpdate: OnUpdate<Props>, getContext: GetContext, setContext: SetContext) -> Cleanup

-- A thing represents an object that can be created, updated, and destroyed.
type Thing<Props> = { update: (new: Props, old: Props?) -> (), destroy: () -> () }

-- Element represents the desired state of a thing at any given point in time.
-- We should replace `props: any` with `props: T` when Luau adds support for recursive types of different generics.
-- See https://github.com/Roblox/luau/pull/86
type Element = { constructor: Constructor<any>, props: any, children: { Element } }

-- A Thingy is a thing but it also stores the props and children that was used to create that thing.
-- The  props and children used to create the thing is important so that we can check if any of the
-- configuration changed to determine whether the thing should be updated.
-- I need a better name for this, or I could just store the props and children in Thing itself.
type Thingy = {
	constructor: Constructor<any>,
	props: any,
	thing: Thing<any>,
	children: { Thingy },
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

-- Destroys the children of a thingy and the thingy itself recursively.
local function destroyRecursive(thingy: Thingy)
	for _, child in thingy.children do
		destroyRecursive(child) -- luau errors on this line for some reason
	end
	thingy.thing.destroy()
end

-- Apply takes an array of thingies and an array of elements and mutates the thingies to match the array of elements.
local function apply(thingies: { Thingy }, elements: { Element }, parentGetContext: GetContext)
	local getContext: GetContext
	-- Remove thingies that no longer exist.
	for i, thingy in thingies do
		if not elements[i] then
			destroyRecursive(thingy)
			thingies[i] = nil
		end
	end

	-- Creates new thingies or updates existing thingies.
	for i, element in elements do
		local existing: Thingy? = thingies[i]
		local thingy: Thingy
		if existing then
			thingy = existing
		end
		if existing and existing.constructor == element.constructor and existing.props ~= element.props then
			existing.thing.update(element.props, existing.props)
			existing.props = element.props
			getContext = existing.getContext
		end
		if not existing or existing.constructor ~= element.constructor then
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
			if existing then
				thingy.thing = thing
			else
				thingy = {
					constructor = element.constructor,
					props = element.props,
					thing = thing,
					children = {},
					getContext = getContext,
				}
			end
		end
		apply(thingy.children, element.children, getContext)
		thingies[i] = thingy
	end
end

local function defaultGetContext(context)
	return context.default
end

local FuelCore = {}

function FuelCore.handle()
	local thingies = {}
	return {
		apply = function(elements: { Element })
			apply(thingies, elements, defaultGetContext)
		end,
	}
end

function FuelCore.thing<T>(constructor: Constructor<T>): (T, children: { Element }) -> Element
	return function(props, children)
		return { props = props, children = children, constructor = constructor }
	end
end

return FuelCore
