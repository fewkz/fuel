--!strict
local parentContext = { default = nil :: Instance? }
local FuelCore = require(script.Parent.Core)
local FuelHooks = require(script.Parent.Hooks)
local FuelRbx = {}
FuelRbx.parentContext = parentContext

FuelRbx.RootInstance = FuelCore.define(function(onUpdate, treeOperations)
	onUpdate(function(props: { instance: Instance })
		treeOperations.setContext(parentContext, props.instance)
		return nil
	end)
	return nil
end)

FuelRbx.InstanceCallback = FuelHooks.statefulComponent(function(hooks, props: { callback: (Instance?) -> () })
	local parent = hooks.useContext(parentContext)
	hooks.useEffect(function()
		task.spawn(props.callback, parent)
		return
	end, { parent, props.callback })
end)

type Align =
	"TopLeft"
	| "TopRight"
	| "BottomLeft"
	| "BottomRight"
	| "Center"
	| "Top"
	| "Left"
	| "Right"
	| "Bottom"

type FrameProps = {
	name: string?,
	size: UDim2?,
	color: Color3?,
}
FuelRbx.Frame = FuelCore.define(function(onUpdate, treeOperations)
	local instance = Instance.new("Frame")
	onUpdate(function(props: FrameProps)
		if props.name then
			instance.Name = props.name
		end
		if props.size then
			instance.Size = props.size
		end
		instance.BackgroundColor3 = if props.color then props.color else Color3.new(1, 1, 1)
		return nil
	end)
	treeOperations.subscribeContext(parentContext, function(parent)
		instance.Parent = parent
	end)
	treeOperations.setContext(parentContext, instance)
	return function()
		treeOperations.setContext(parentContext, nil) -- Set parent context to nil so that :Destroy() doesn't destroy children.
		instance:Destroy()
	end
end)

type TextLabelProps = {
	name: string?,
	color: Color3?,
	textColor: Color3?,
	borderColor: Color3?,
	borderSize: number?,
	textAlign: Align?,
	position: UDim2 | Align | nil,
	anchorPoint: Vector2 | Align | nil,
}
FuelRbx.TextLabel = FuelCore.define(function(onUpdate, treeOperations)
	local instance = Instance.new("TextLabel")
	onUpdate(function(props: TextLabelProps)
		if props.name then
			instance.Name = props.name
		end
		instance.BackgroundColor3 = if props.color then props.color else Color3.new(1, 1, 1)
		instance.TextColor3 = if props.textColor then props.textColor else Color3.new(0, 0, 0)
		instance.BorderColor3 = if props.borderColor then props.borderColor else Color3.new(0, 0, 0)
		instance.BorderSizePixel = if props.borderSize then props.borderSize else 0
		if
			props.textAlign == "BottomLeft"
			or props.textAlign == "Bottom"
			or props.textAlign == "BottomRight"
		then
			instance.TextYAlignment = Enum.TextYAlignment.Bottom
		elseif props.textAlign == "Left" or props.textAlign == "Center" or props.textAlign == "Right" then
			instance.TextYAlignment = Enum.TextYAlignment.Center
		else
			instance.TextYAlignment = Enum.TextYAlignment.Top
		end
		if
			props.textAlign == "TopRight"
			or props.textAlign == "Right"
			or props.textAlign == "BottomRight"
		then
			instance.TextXAlignment = Enum.TextXAlignment.Right
		elseif props.textAlign == "Top" or props.textAlign == "Center" or props.textAlign == "Bottom" then
			instance.TextXAlignment = Enum.TextXAlignment.Center
		else
			instance.TextXAlignment = Enum.TextXAlignment.Left
		end
		if props.position == "TopLeft" then
			instance.Position = UDim2.fromScale(0, 0)
		elseif props.position == "Top" then
			instance.Position = UDim2.fromScale(0.5, 0)
		elseif props.position == "TopRight" then
			instance.Position = UDim2.fromScale(1, 0)
		elseif props.position == "Left" then
			instance.Position = UDim2.fromScale(0, 0.5)
		elseif props.position == "Center" then
			instance.Position = UDim2.fromScale(0.5, 0.5)
		elseif props.position == "Right" then
			instance.Position = UDim2.fromScale(1, 0.5)
		elseif props.position == "BottomLeft" then
			instance.Position = UDim2.fromScale(0, 1)
		elseif props.position == "Bottom" then
			instance.Position = UDim2.fromScale(0.5, 1)
		elseif props.position == "BottomRight" then
			instance.Position = UDim2.fromScale(1, 1)
		elseif typeof(props.position) == "UDim2" then
			instance.Position = props.position
		end
		if props.anchorPoint == "TopLeft" then
			instance.AnchorPoint = Vector2.new(0, 0)
		elseif props.anchorPoint == "Top" then
			instance.AnchorPoint = Vector2.new(0.5, 0)
		elseif props.anchorPoint == "TopRight" then
			instance.AnchorPoint = Vector2.new(1, 0)
		elseif props.anchorPoint == "Left" then
			instance.AnchorPoint = Vector2.new(0, 0.5)
		elseif props.anchorPoint == "Center" then
			instance.AnchorPoint = Vector2.new(0.5, 0.5)
		elseif props.anchorPoint == "Right" then
			instance.AnchorPoint = Vector2.new(1, 0.5)
		elseif props.anchorPoint == "BottomLeft" then
			instance.AnchorPoint = Vector2.new(0, 1)
		elseif props.anchorPoint == "Bottom" then
			instance.AnchorPoint = Vector2.new(0.5, 1)
		elseif props.anchorPoint == "BottomRight" then
			instance.AnchorPoint = Vector2.new(1, 1)
		elseif typeof(props.anchorPoint) == "Vector2" then
			instance.AnchorPoint = props.anchorPoint
		end
		return nil
	end)
	treeOperations.subscribeContext(parentContext, function(parent)
		instance.Parent = parent
	end)
	treeOperations.setContext(parentContext, instance)
	return function()
		treeOperations.setContext(parentContext, nil) -- Set parent context to nil so that :Destroy() doesn't destroy children.
		instance:Destroy()
	end
end)

type TextButtonProps = {
	name: string?,
	text: string?,
	automaticSize: Enum.AutomaticSize?,
	color: Color3?,
	textColor: Color3?,
	borderColor: Color3?,
	borderSize: number?,
	textAlign: Align?,
	position: UDim2 | Align | nil,
	anchorPoint: Vector2 | Align | nil,
	onActivated: () -> ()?,
}
FuelRbx.TextButton = FuelCore.define(function(onUpdate, treeOperations)
	local instance = Instance.new("TextButton")
	local lastProps: TextButtonProps?
	local lastActivatedConn
	onUpdate(function(props: TextButtonProps)
		if props.name then
			instance.Name = props.name
		end
		if props.text then
			instance.Text = props.text
		end
		if props.automaticSize then
			instance.AutomaticSize = props.automaticSize
		end
		instance.BackgroundColor3 = if props.color then props.color else Color3.new(1, 1, 1)
		instance.TextColor3 = if props.textColor then props.textColor else Color3.new(0, 0, 0)
		instance.BorderColor3 = if props.borderColor then props.borderColor else Color3.new(0, 0, 0)
		instance.BorderSizePixel = if props.borderSize then props.borderSize else 0
		if
			props.textAlign == "BottomLeft"
			or props.textAlign == "Bottom"
			or props.textAlign == "BottomRight"
		then
			instance.TextYAlignment = Enum.TextYAlignment.Bottom
		elseif props.textAlign == "Left" or props.textAlign == "Center" or props.textAlign == "Right" then
			instance.TextYAlignment = Enum.TextYAlignment.Center
		else
			instance.TextYAlignment = Enum.TextYAlignment.Top
		end
		if
			props.textAlign == "TopRight"
			or props.textAlign == "Right"
			or props.textAlign == "BottomRight"
		then
			instance.TextXAlignment = Enum.TextXAlignment.Right
		elseif props.textAlign == "Top" or props.textAlign == "Center" or props.textAlign == "Bottom" then
			instance.TextXAlignment = Enum.TextXAlignment.Center
		else
			instance.TextXAlignment = Enum.TextXAlignment.Left
		end
		if props.position == "TopLeft" then
			instance.Position = UDim2.fromScale(0, 0)
		elseif props.position == "Top" then
			instance.Position = UDim2.fromScale(0.5, 0)
		elseif props.position == "TopRight" then
			instance.Position = UDim2.fromScale(1, 0)
		elseif props.position == "Left" then
			instance.Position = UDim2.fromScale(0, 0.5)
		elseif props.position == "Center" then
			instance.Position = UDim2.fromScale(0.5, 0.5)
		elseif props.position == "Right" then
			instance.Position = UDim2.fromScale(1, 0.5)
		elseif props.position == "BottomLeft" then
			instance.Position = UDim2.fromScale(0, 1)
		elseif props.position == "Bottom" then
			instance.Position = UDim2.fromScale(0.5, 1)
		elseif props.position == "BottomRight" then
			instance.Position = UDim2.fromScale(1, 1)
		elseif typeof(props.position) == "UDim2" then
			instance.Position = props.position
		end
		if props.anchorPoint == "TopLeft" then
			instance.AnchorPoint = Vector2.new(0, 0)
		elseif props.anchorPoint == "Top" then
			instance.AnchorPoint = Vector2.new(0.5, 0)
		elseif props.anchorPoint == "TopRight" then
			instance.AnchorPoint = Vector2.new(1, 0)
		elseif props.anchorPoint == "Left" then
			instance.AnchorPoint = Vector2.new(0, 0.5)
		elseif props.anchorPoint == "Center" then
			instance.AnchorPoint = Vector2.new(0.5, 0.5)
		elseif props.anchorPoint == "Right" then
			instance.AnchorPoint = Vector2.new(1, 0.5)
		elseif props.anchorPoint == "BottomLeft" then
			instance.AnchorPoint = Vector2.new(0, 1)
		elseif props.anchorPoint == "Bottom" then
			instance.AnchorPoint = Vector2.new(0.5, 1)
		elseif props.anchorPoint == "BottomRight" then
			instance.AnchorPoint = Vector2.new(1, 1)
		elseif typeof(props.anchorPoint) == "Vector2" then
			instance.AnchorPoint = props.anchorPoint
		end
		if not lastProps or props.onActivated ~= lastProps.onActivated then
			if lastActivatedConn then
				lastActivatedConn:Disconnect()
			end
			if props.onActivated then
				lastActivatedConn = instance.Activated:Connect(props.onActivated)
			end
		end
		lastProps = props
		return nil
	end)
	treeOperations.subscribeContext(parentContext, function(parent)
		instance.Parent = parent
	end)
	treeOperations.setContext(parentContext, instance)
	return function()
		treeOperations.setContext(parentContext, nil) -- Set parent context to nil so that :Destroy() doesn't destroy children.
		instance:Destroy()
	end
end)

type UIListLayoutProps = {
	direction: "Horizontal" | "Vertical",
	align: Align?,
}
FuelRbx.UIListLayout = FuelCore.define(function(onUpdate, treeOperations)
	local instance = Instance.new("UIListLayout")
	onUpdate(function(props: UIListLayoutProps)
		instance.FillDirection = if props.direction == "Horizontal"
			then Enum.FillDirection.Horizontal
			else Enum.FillDirection.Vertical
		if props.align == "BottomLeft" or props.align == "Bottom" or props.align == "BottomRight" then
			instance.VerticalAlignment = Enum.VerticalAlignment.Bottom
		elseif props.align == "Left" or props.align == "Center" or props.align == "Right" then
			instance.VerticalAlignment = Enum.VerticalAlignment.Center
		else
			instance.VerticalAlignment = Enum.VerticalAlignment.Top
		end
		if props.align == "TopRight" or props.align == "Right" or props.align == "BottomRight" then
			instance.HorizontalAlignment = Enum.HorizontalAlignment.Right
		elseif props.align == "Top" or props.align == "Center" or props.align == "Bottom" then
			instance.HorizontalAlignment = Enum.HorizontalAlignment.Center
		else
			instance.HorizontalAlignment = Enum.HorizontalAlignment.Left
		end
		return nil
	end)
	treeOperations.subscribeContext(parentContext, function(parent)
		instance.Parent = parent
	end)
	treeOperations.setContext(parentContext, instance)
	return function()
		treeOperations.setContext(parentContext, nil) -- Set parent context to nil so that :Destroy() doesn't destroy children.
		instance:Destroy()
	end
end)

type UIPaddingProps = {
	top: UDim?,
	left: UDim?,
	right: UDim?,
	bottom: UDim?,
}
FuelRbx.UIPadding = FuelCore.define(function(onUpdate, treeOperations)
	local instance = Instance.new("UIPadding")
	onUpdate(function(props: UIPaddingProps)
		if props.top then
			instance.PaddingTop = props.top
		end
		if props.left then
			instance.PaddingLeft = props.left
		end
		if props.right then
			instance.PaddingRight = props.right
		end
		if props.bottom then
			instance.PaddingBottom = props.bottom
		end
		return nil
	end)
	treeOperations.subscribeContext(parentContext, function(parent)
		instance.Parent = parent
	end)
	treeOperations.setContext(parentContext, instance)
	return function()
		treeOperations.setContext(parentContext, nil) -- Set parent context to nil so that :Destroy() doesn't destroy children.
		instance:Destroy()
	end
end)

type UICornerProps = {
	radius: UDim?,
}
FuelRbx.UICorner = FuelCore.define(function(onUpdate, treeOperations)
	local instance = Instance.new("UICorner")
	onUpdate(function(props: UICornerProps)
		if props.radius then
			instance.CornerRadius = props.radius
		end
		return nil
	end)
	treeOperations.subscribeContext(parentContext, function(parent)
		instance.Parent = parent
	end)
	treeOperations.setContext(parentContext, instance)
	return function()
		treeOperations.setContext(parentContext, nil) -- Set parent context to nil so that :Destroy() doesn't destroy children.
		instance:Destroy()
	end
end)

return FuelRbx
