--!strict
local Fuel = {}
local FuelCore = require(script.Core)
Fuel.Core = FuelCore
local FuelHooks = require(script.Hooks)
Fuel.Hooks = FuelHooks
Fuel.Rbx = require(script.Rbx)

export type Context<T> = FuelCore.Context<T>
export type Element = FuelCore.Element

export type Hooks = FuelHooks.Hooks

return Fuel
