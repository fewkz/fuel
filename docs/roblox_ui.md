# Using Fuel for Roblox UI

Fuel comes bundled with a library of resource definitions for Roblox UI instances. This library is
designed to provide light abstractions over Roblox's API to make writing UI code more elegant. Many
resource properties are simply the same name as their instance counterparts but in camelcase. For
example, `AutomaticSize` is `automaticSize`. However, some properties have shorter names that are
less verbose. For example, `BackgroundColor3` is `color`.

## Notable differences

- `HorizontalAlignment` and `VerticalAlignment` properties are replaced with an `align` prop of type
  `Align`.
- `TextXAlignment` and `TextYAlignment` properties are replaced with a `textAlign` prop of type
  `Align`.
- Properties of enums are replaced with string literals.
- `position` and `anchorPoint` properties support the `Align` type for convenience.
- `ScreenGui`'s `Enabled` property and the `Visible` property of gui objects are controlled with the
  `hide` property, setting it to true will set `Visible` or `Enabled` to false.
- The `autoLocalize` property is only able to be set on objects with a `text` field. An
  `autoLocalizeContext` is provided for providing a default `AutoLocalize` value to descendants.

## Custom types

```lua
Align: "TopLeft"    | "Top"    | "TopRight"
     | "Left"       | "Center" | "Right"
     | "BottomLeft" | "Bottom" | "BottomRight"
```
