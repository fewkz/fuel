local FuelCore = require(script.Parent.Core)

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

local function makeHooks(
	pointerRef: { value: number },
	treeOperations: FuelCore.TreeOperations,
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
	function hooks.useContext<T>(context: FuelCore.Context<T>): T
		local contextValue = hooks.useMemo(function()
			return { value = context.default }
		end)
		local isSync = true
		hooks.useEffect(function()
			return treeOperations.subscribeContext(context, function(value)
				if value ~= contextValue.value then
					contextValue.value = value
					-- Only rerender if subscribe didn't emit synchronously.
					if not isSync then
						-- Context changing should always trigger a rerender.
						-- For example, Roblox instance components being unmounted
						-- will set parent context to nil before they're destroyed
						-- so that children have a chance to unparent themselves so
						-- they don't get destroyed as well.
						rerender()
					end
				end
			end)
		end, { context })
		isSync = false
		return contextValue.value
	end
	return hooks, function()
		for _, cleanup in cleanups do
			cleanup()
		end
	end
end

export type Hooks = typeof(makeHooks(unpack({} :: any)))

local FuelHooks = {}

function FuelHooks.statefulComponent<Props>(callback: (hooks: Hooks, props: Props) -> ())
	return FuelCore.thing(function(onUpdate, treeOperations)
		local hooks, cleanupHooks
		local hooksPointer = { value = 0 }
		local lastProps: Props
		local queuedRerender = false
		local function rerender(props: Props)
			lastProps = props
			hooksPointer.value = 0
			queuedRerender = false
			callback(hooks, props)
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
		return cleanupHooks
	end)
end

function FuelHooks.statefulElements<Props>(callback: (hooks: Hooks, props: Props) -> { FuelCore.Element })
	return FuelCore.thing(function(onUpdate, treeOperations)
		local handle = FuelCore.handle()
		local hooks, cleanupHooks
		local hooksPointer = { value = 0 }
		local lastProps: Props
		local queuedRerender = false
		local function rerender(props: Props)
			lastProps = props
			hooksPointer.value = 0
			queuedRerender = false
			handle.apply(callback(hooks, props))
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
			handle.apply({})
		end
	end)
end

function FuelHooks.statefulElement<Props>(callback: (hooks: Hooks, props: Props) -> FuelCore.Element)
	return FuelHooks.statefulElements(function(hooks, props: Props)
		return { callback(hooks, props) }
	end)
end

return FuelHooks
