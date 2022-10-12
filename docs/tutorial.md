# Tutorial

Make sure to follow the installation guide and have Fuel in ReplicatedStorage.Packages before
following the tutorial.

## Simple "Hello World!" UI

Let's create a simple UI that displays the text "Hello World".

Create a `LocalScript` in `StarterPlayer.StarterPlayerScripts`.

We'll start by importing Fuel into our script and getting a reference to `PlayerGui`.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Fuel = require(ReplicatedStorage.Packages.Fuel)

local PlayerGui = Players.LocalPlayer.PlayerGui
```

We can now create an "element" that represents how we want our UI to look.

```lua
local app = Fuel.Rbx.RootInstance({ instance = PlayerGui }, {
    Fuel.Rbx.ScreenGui({}, {
        Fuel.Rbx.TextLabel({ text = "Hello World!", size = UDim2.fromScale(1, 1), opacity = 0 })
    })
})
```

Then we need to have Fuel create this tree of elements by "applying" it to a new "handle".

```lua
Fuel.Core.handle().apply({ app })
```

Finished code:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Fuel = require(ReplicatedStorage.Packages.Fuel)

local PlayerGui = Players.LocalPlayer.PlayerGui

local app = Fuel.Rbx.RootInstance({ instance = PlayerGui }, {
    Fuel.Rbx.ScreenGui({}, {
        Fuel.Rbx.TextLabel({ text = "Hello World!", size = UDim2.fromScale(1, 1), opacity = 0 })
    })
})

Fuel.Core.handle().apply({ app })
```

## Let's create a counter!

This next example will showcase a UI that updates over time. Let's import Fuel, and create a new
handle.

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Fuel = require(ReplicatedStorage.Packages.Fuel)

local PlayerGui = Players.LocalPlayer.PlayerGui

local handle = Fuel.Core.handle()
```

Now, we can use a loop to create an element and apply it to our handle every second.

```lua
local count = 0
while true do
    local text = if count == 1
        then "It's been "..count.." second"
        else "It's been "..count.." seconds"
    local app = Fuel.Rbx.RootInstance({ instance = PlayerGui }, {
        Fuel.Rbx.ScreenGui({}, {
            Fuel.Rbx.TextLabel({
                text = text,
                size = UDim2.fromScale(1, 1),
                opacity = 0
            })
        })
    })
    handle.apply({ app })
    count += 1
    task.wait(1)
end
```

## Improving the counter via functional components.

We can improve the counter in the previous example by making it a component. Making it into a
component will allow us to reuse it across our UI.

Let's start by just importing Fuel:

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Fuel = require(ReplicatedStorage.Packages.Fuel)
```

Now, let's create a functional component for a single element.

```lua
local Counter = Fuel.Core.statefulElement(function(hooks, props: {
    -- Define the properties our component can take
    size: UDim2,
    position: Fuel.Align,
    anchorPoint: Fuel.Align,
})
    local count, setCount = hooks.useState(0)
    local text = if count == 1
        then "It's been "..count.." second"
        else "It's been "..count.." seconds"
    -- The effect will run whenever count changes, and increment the count
    -- a second later, creating an infinite loop.
    hooks.useEffect(function()
        local thread = task.delay(1, setCount, function(count)
            return count + 1
        end)
        -- Cleanup method will run when the component is going to be unmounted
        return function()
            task.cancel(thread)
        end
    end, { count })
    -- In the current version of Fuel, context is not propagated to elements
    -- created by a component, so we must make the component consume the parent
    -- context and pass it explicitly. This should change in future versions!
    local parent = hooks.useContext(Fuel.Rbx.parentContext)
    return Fuel.Rbx.RootInstance({ instance = parent }, {
        Fuel.Rbx.TextLabel({
            text = text,
            size = props.size,
            position = props.position,
            anchorPoint = props.anchorPoint,
            opacity = 0
        })
    })
end)
```

Now that we've created a `Counter` component, we can use it across our code like so:

```lua
local app = Fuel.Rbx.RootInstance({ instance = PlayerGui }, {
    Fuel.Rbx.ScreenGui({}, {
        Counter({
            size = UDim2.fromScale(1, 0.5),
            position = "Top",
            anchorPoint = "Top",
        }),
    })
})
local handle = Fuel.Core.handle()
handle.apply({ app })

-- After 5 seconds, create a new counter:
local app = Fuel.Rbx.RootInstance({ instance = PlayerGui }, {
    Fuel.Rbx.ScreenGui({}, {
        Counter({
            size = UDim2.fromScale(1, 0.5),
            position = "Top",
            anchorPoint = "Top",
        }),
        Counter({
            size = UDim2.fromScale(1, 0.5),
            position = "Bottom",
            anchorPoint = "Bottom",
        }),
    })
})
handle.apply({ app })
```

In this example, the second counter will have it's own distinct count 5 seconds behind.
