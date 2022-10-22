--!strict
local core = require("core")

local passedTests = {}
local failedTests = {}

local function test(name: string, body: () -> ())
	local suc = xpcall(body, function(msg)
		table.insert(failedTests, { name = name, msg = msg })
	end)
	if suc then
		table.insert(passedTests, name)
	end
end

local blankComponent = core.thing(function()
	return
end)

local function makeTestComponent(lifeRef: { string })
	return core.thing(function(onUpdate, operations)
		table.insert(lifeRef, "create")
		onUpdate(function(props: { value: string })
			table.insert(lifeRef, "updated with " .. props.value)
			return
		end)
		return function()
			table.insert(lifeRef, "destroy")
		end
	end)
end

local function makeContextReader(context, valueHistoryRef)
	return core.thing(function(_, operations)
		operations.subscribeContext(context, function(value)
			table.insert(valueHistoryRef, value)
		end)
		return
	end)
end

test("Applying creates, updates, and destroys components", function()
	local lifeRef = {}
	local TestComponent = makeTestComponent(lifeRef)

	local handle = core.handle()
	handle.apply({ TestComponent({ value = "foo" }) }) -- create & update
	handle.apply({ TestComponent({ value = "foo" }) }) -- update
	handle.apply({}) -- destroy
	handle.apply({ TestComponent({ value = "foo" }) }) -- create & update
	handle.apply({}) -- destroy

	assert(lifeRef[1] == "create", "Expected create, got " .. tostring(lifeRef[1]))
	assert(lifeRef[2] == "updated with foo", "Expected 'updated with foo', got " .. tostring(lifeRef[2]))
	assert(lifeRef[3] == "updated with foo", "Expected 'updated with foo', got " .. tostring(lifeRef[3]))
	assert(lifeRef[4] == "destroy", "Expected destroy, got " .. tostring(lifeRef[4]))
	assert(lifeRef[5] == "create", "Expected create, got " .. tostring(lifeRef[5]))
	assert(lifeRef[6] == "updated with foo", "Expected 'updated with foo', got " .. tostring(lifeRef[6]))
	assert(lifeRef[7] == "destroy", "Expected destroy, got " .. tostring(lifeRef[7]))
	assert(#lifeRef == 7, "Expected 7 life events, got " .. #lifeRef)
end)

test("Applying resources of different definitions should create and update the correct resources", function()
	local lifeRef1 = {}
	local lifeRef2 = {}
	local TestComponent1 = makeTestComponent(lifeRef1)
	local TestComponent2 = makeTestComponent(lifeRef2)

	local handle = core.handle()
	handle.apply({ TestComponent1({ value = "1" }) }) -- create & update
	handle.apply({ TestComponent2({ value = "2" }) }) -- destroys old, create & update
	handle.apply({})

	assert(lifeRef1[1] == "create", "Expected create, got " .. tostring(lifeRef1[1]))
	assert(lifeRef1[2] == "updated with 1", "Expected 'updated with 1', got " .. tostring(lifeRef1[2]))
	assert(lifeRef1[3] == "destroy", "Expected destroy, got " .. tostring(lifeRef1[3]))
	assert(#lifeRef1 == 3, "Expected 3 life events, got " .. #lifeRef1)

	assert(lifeRef2[1] == "create", "Expected create, got " .. tostring(lifeRef2[1]))
	assert(lifeRef2[2] == "updated with 2", "Expected 'updated with 2', got " .. tostring(lifeRef2[2]))
	assert(lifeRef2[3] == "destroy", "Expected destroy, got " .. tostring(lifeRef2[3]))
	assert(#lifeRef2 == 3, "Expected 3 life events, got " .. #lifeRef2)
end)

-- There was a bug that caused this code to not work, due to Provider being updated with blank's props (empty)
-- So I'm just going to put it here as a test case. The bug was fixed in e228fd0e36e8ea426f256dc4953c4101d29f9d9e
test("Applying Blank component -> Provider -> Blank component -> Provider works", function()
	local testContext = { default = "default" }
	local handle = core.handle()
	handle.apply({ blankComponent({}) })
	handle.apply({ core.Provider({ context = testContext, value = "1" })})
	handle.apply({ blankComponent({}) })
	handle.apply({ core.Provider({ context = testContext, value = "2" })})
end)

test("Context provider being removed should propogate it's parent's context downstream", function()
	local testContext = { default = "default" }
	local valueHistory = {}
	local contextReader = makeContextReader(testContext, valueHistory)

	local handle = core.handle()
	handle.apply({ core.Provider({ context = testContext, value = "1" }, { contextReader({}) }) })
	handle.apply({ blankComponent({}, { contextReader({}) }) })

	assert(valueHistory[1] == "1", "Expected 1, got " .. tostring(valueHistory[1]))
	assert(valueHistory[2] == "default", "Expected default, got " .. tostring(valueHistory[2]))
	assert(#valueHistory == 2, "Expected 2 context values, got " .. #valueHistory)
end)

test("Context is passed to components", function()
	local testContext = { default = "default" }
	local valueHistory = {}
	local contextReader = makeContextReader(testContext, valueHistory)

	local handle = core.handle()
	handle.apply({ blankComponent({}, { contextReader({}) }) })
	handle.apply({ core.Provider({ context = testContext, value = "1" }, { contextReader({}) }) })
	handle.apply({ blankComponent({}, { contextReader({}) }) })
	handle.apply({ core.Provider({ context = testContext, value = "2" }, { contextReader({}) }) })

	assert(valueHistory[1] == "default", "Expected default, got " .. tostring(valueHistory[1]))
	assert(valueHistory[2] == "1", "Expected 1, got " .. tostring(valueHistory[2]))
	assert(valueHistory[3] == "default", "Expected default, got " .. tostring(valueHistory[3]))
	assert(valueHistory[4] == "2", "Expected 2, got " .. tostring(valueHistory[4]))
	assert(#valueHistory == 4, "Expected 4 context values, got " .. #valueHistory)
end)

test("Context subscriptions are unsubscribed when resource is destroyed", function()
	local testContext = { default = "default" }
	local valueHistory = {}
	local contextReader = makeContextReader(testContext, valueHistory)

	local handle = core.handle()
	handle.apply({ blankComponent({}, { contextReader({}) }) })
	handle.apply({ core.Provider({ context = testContext, value = "1" }, { contextReader({}) }) })
	handle.apply({ core.Provider({ context = testContext, value = "2" }, { contextReader({}) }) })

	assert(#valueHistory == 3, "Expected 3 value changes, got " .. #valueHistory)
	assert(valueHistory[1] == "default", "Expected default, got " .. tostring(valueHistory[1]))
	assert(valueHistory[2] == "1", "Expected 1, got " .. tostring(valueHistory[2]))
	assert(valueHistory[3] == "2", "Expected 2, got " .. tostring(valueHistory[3]))
end)

local red = "\27[31m"
local green = "\27[32m"
local bold = "\27[1m"
local reset = "\27[0m"
local underline = "\27[4m"

for _, passedTest in passedTests do
	print(`{green}{underline}{passedTest}{reset}`)
end
for _, failedTest in failedTests do
	print(`{red}{underline}{failedTest.name}{reset}`)
	print(failedTest.msg)
end
if #failedTests > 0 then
	error(`{red}{bold}{#failedTests} tests failed{reset}`, 0)
else
	print(`{green}{bold}All tests passed!{reset}`)
end
