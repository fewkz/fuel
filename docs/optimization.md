# Optimizations

This page goes over tricks you can do to optimize your UI code.

## Use stable keys

Fuel determines which resource an element represents by using the key of the element in the children
table. For UI that represents lists of data, such as a player list or inventory; you should set the
key of each element to represent some sort of id for each item. Key is purely optional, since Luau
will automatically key elements by their position in the table.

## Memoize properties

By default, Fuel will trigger an update on a resource every time there's an application. Fuel does
not perform shallow comparison on the properties table to see if the resource changed. However, Fuel
does perform an exact comparison on the properties table, so you can implement your own memoization
code.

```lua
-- Make a weakly referenced table, Fuel holds a strong reference to
-- the properties of any resource that exists, so storing a weak reference
-- will allow the cache to be garbaged collected.
local propsCache = setmetatable({}, { __mode = "v" })
-- Rudimentary props memoization that only supports `text` prop.
local function memoizeProps(props)
    for cachedProps in propsCache do
        if cachedProps.text == props.text then
            return cachedProps
        end
    end
    propsCache[props] = true
end

local element1 = Fuel.Rbx.TextLabel(memoizeProps({ text = "hi!" }))
local element2 = Fuel.Rbx.TextLabel(memoizeProps({ text = "hi!" }))

local handle = Fuel.Core.handle()
handle.apply({ element1 })
handle.apply({ element2 }) -- Won't trigger an update, since the properties table didn't change.
```
