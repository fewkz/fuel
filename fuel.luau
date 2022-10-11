--!strict
local Fuel = {}
local FuelCore = require(script.Core)
Fuel.Core = FuelCore
Fuel.Rbx = require(script.Rbx)

export type Hooks = FuelCore.Hooks

return Fuel
