# Welcome to Fuel!

Fuel is a declarative UI library for Luau inspired by React designed for usage in Roblox.

## Features

- Define your UI declaratively and let Fuel modify underlying instance as neccessary.
- Full Luau support, providing autocomplete and diagnostic for invalid properties.
- Built-in support for functional components with hooks.
- Less verbose Roblox instance properties for more elegant UI code.

## Example

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Fuel = require(ReplicatedStorage.Packages.Fuel)

local app = Fuel.Rbx.RootInstance({ instance = Players.LocalPlayer.PlayerGui }, {
    Fuel.Rbx.ScreenGui({}, {
        Fuel.Rbx.TextLabel({
            text = "Hello World!",
            size = UDim2.fromScale(1, 1),
            opacity = 0
        })
    })
})
Fuel.Core.handle().apply({ app })
```
