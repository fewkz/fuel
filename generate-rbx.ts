interface Prop {
  inPropType: string;
  beforeOnUpdate?: string;
  inOnUpdate: string;
  requiresLastProps?: true;
}

function basicProperty(
  baseName: string,
  customName: string,
  typeName: string,
): Prop {
  return {
    inPropType: `${customName}: ${typeName}?`,
    inOnUpdate: [
      `if props.${customName} then`,
      `    instance.${baseName} = props.${customName}`,
      "end",
    ].join("\n"),
  };
}

function defaultProperty(
  baseName: string,
  customName: string,
  typeName: string,
  defaultValue: string,
): Prop {
  return {
    inPropType: `${customName}: ${typeName}?`,
    inOnUpdate:
      `instance.${baseName} = if props.${customName} then props.${customName} else ${defaultValue}`,
  };
}

function callback(
  baseName: string,
  customName: string,
): Prop {
  return {
    inPropType: `${customName}: () -> ()?`,
    beforeOnUpdate: `local last${baseName}Conn`,
    inOnUpdate: [
      `if not lastProps or props.${customName} ~= lastProps.${customName} then`,
      `    if last${baseName}Conn then`,
      `        last${baseName}Conn:Disconnect()`,
      "    end",
      `    if props.${customName} then`,
      `        last${baseName}Conn = instance.${baseName}:Connect(props.${customName})`,
      "    end",
      "end",
    ].join("\n"),
    requiresLastProps: true,
  };
}

const anchorPointProp: Prop = {
  inPropType: "anchorPoint: Vector2 | Align | nil",
  inOnUpdate: [
    'if props.anchorPoint == "TopLeft" then',
    "    instance.AnchorPoint = Vector2.new(0, 0)",
    'elseif props.anchorPoint == "Top" then',
    "    instance.AnchorPoint = Vector2.new(0.5, 0)",
    'elseif props.anchorPoint == "TopRight" then',
    "    instance.AnchorPoint = Vector2.new(1, 0)",
    'elseif props.anchorPoint == "Left" then',
    "    instance.AnchorPoint = Vector2.new(0, 0.5)",
    'elseif props.anchorPoint == "Center" then',
    "    instance.AnchorPoint = Vector2.new(0.5, 0.5)",
    'elseif props.anchorPoint == "Right" then',
    "    instance.AnchorPoint = Vector2.new(1, 0.5)",
    'elseif props.anchorPoint == "BottomLeft" then',
    "    instance.AnchorPoint = Vector2.new(0, 1)",
    'elseif props.anchorPoint == "Bottom" then',
    "    instance.AnchorPoint = Vector2.new(0.5, 1)",
    'elseif props.anchorPoint == "BottomRight" then',
    "    instance.AnchorPoint = Vector2.new(1, 1)",
    'elseif typeof(props.anchorPoint) == "Vector2" then',
    "    instance.AnchorPoint = props.anchorPoint",
    "end",
  ].join("\n"),
};

const positionProp: Prop = {
  inPropType: "position: UDim2 | Align | nil",
  inOnUpdate: [
    'if props.position == "TopLeft" then',
    "    instance.Position = UDim2.fromScale(0, 0)",
    'elseif props.position == "Top" then',
    "    instance.Position = UDim2.fromScale(0.5, 0)",
    'elseif props.position == "TopRight" then',
    "    instance.Position = UDim2.fromScale(1, 0)",
    'elseif props.position == "Left" then',
    "    instance.Position = UDim2.fromScale(0, 0.5)",
    'elseif props.position == "Center" then',
    "    instance.Position = UDim2.fromScale(0.5, 0.5)",
    'elseif props.position == "Right" then',
    "    instance.Position = UDim2.fromScale(1, 0.5)",
    'elseif props.position == "BottomLeft" then',
    "    instance.Position = UDim2.fromScale(0, 1)",
    'elseif props.position == "Bottom" then',
    "    instance.Position = UDim2.fromScale(0.5, 1)",
    'elseif props.position == "BottomRight" then',
    "    instance.Position = UDim2.fromScale(1, 1)",
    'elseif typeof(props.position) == "UDim2" then',
    "    instance.Position = props.position",
    "end",
  ].join("\n"),
};

// This prop is for TextLabels and TextButtons and controls TextXAlignment and TextYAlignment
const textAlignProp: Prop = {
  inPropType: "textAlign: Align?",
  inOnUpdate: [
    "if",
    '    props.textAlign == "BottomLeft"',
    '    or props.textAlign == "Bottom"',
    '    or props.textAlign == "BottomRight"',
    "then",
    "    instance.TextYAlignment = Enum.TextYAlignment.Bottom",
    'elseif props.textAlign == "Left" or props.textAlign == "Center" or props.textAlign == "Right" then',
    "    instance.TextYAlignment = Enum.TextYAlignment.Center",
    "else",
    "    instance.TextYAlignment = Enum.TextYAlignment.Top",
    "end",
    "if",
    '    props.textAlign == "TopRight"',
    '    or props.textAlign == "Right"',
    '    or props.textAlign == "BottomRight"',
    "then",
    "    instance.TextXAlignment = Enum.TextXAlignment.Right",
    'elseif props.textAlign == "Top" or props.textAlign == "Center" or props.textAlign == "Bottom" then',
    "    instance.TextXAlignment = Enum.TextXAlignment.Center",
    "else",
    "    instance.TextXAlignment = Enum.TextXAlignment.Left",
    "end",
  ].join("\n"),
};

// This prop is for UIGridStyleLayout and affects the FillDirection property.
const directionProp: Prop = {
  inPropType: 'direction: "Horizontal" | "Vertical"',
  inOnUpdate:
    'instance.FillDirection = if props.direction == "Horizontal" then Enum.FillDirection.Horizontal else Enum.FillDirection.Vertical',
};

// This prop is for UIGridStyleLayout and affects the HorizontalAlignment and VerticalAlignment properties.
const alignProp: Prop = {
  inPropType: "align: Align?",
  inOnUpdate: [
    'if props.align == "BottomLeft" or props.align == "Bottom" or props.align == "BottomRight" then',
    "    instance.VerticalAlignment = Enum.VerticalAlignment.Bottom",
    'elseif props.align == "Left" or props.align == "Center" or props.align == "Right" then',
    "    instance.VerticalAlignment = Enum.VerticalAlignment.Center",
    "else",
    "    instance.VerticalAlignment = Enum.VerticalAlignment.Top",
    "end",
    'if props.align == "TopRight" or props.align == "Right" or props.align == "BottomRight" then',
    "    instance.HorizontalAlignment = Enum.HorizontalAlignment.Right",
    'elseif props.align == "Top" or props.align == "Center" or props.align == "Bottom" then',
    "    instance.HorizontalAlignment = Enum.HorizontalAlignment.Center",
    "else",
    "    instance.HorizontalAlignment = Enum.HorizontalAlignment.Left",
    "end",
  ].join("\n"),
};

function instance(name: string, props: Prop[]) {
  const propsTypeBody = props.map((prop) => prop.inPropType).join(",");
  const requiresLastProps = props.findIndex((prop) => prop.requiresLastProps) !== -1;
  let beforeOnUpdateBody = props
    .filter((prop) => prop.beforeOnUpdate !== undefined)
    .map((prop) => prop.beforeOnUpdate).join("\n");
  let onUpdateBody = props.map((prop) => prop.inOnUpdate).join("\n");
  if (requiresLastProps) {
    beforeOnUpdateBody = `local lastProps: ${name}Props?\n` + beforeOnUpdateBody;
    onUpdateBody += "\nlastProps = props";
  }
  return [
    `type ${name}Props = {\n${propsTypeBody}}`,
    `FuelRbx.${name} = FuelCore.thing(function(onUpdate, treeOperations)`,
    `    local instance = Instance.new("${name}")`,
    beforeOnUpdateBody,
    `    onUpdate(function(props: ${name}Props)`,
    onUpdateBody,
    "        return nil",
    "    end)",
    "    treeOperations.subscribeContext(parentContext, function(parent)",
    "        instance.Parent = parent",
    "    end)",
    "    treeOperations.setContext(parentContext, instance)",
    "    return function()",
    "        treeOperations.setContext(parentContext, nil) -- Set parent context to nil so that :Destroy() doesn't destroy children.",
    "        instance:Destroy()",
    "    end",
    "end)",
  ].filter((s) => s).join("\n") + "\n";
}

console.log([
  "--!strict",
  "local parentContext = { default = nil :: Instance? }",
  "local FuelCore = require(script.Parent.Core)",
  "local FuelHooks = require(script.Parent.Hooks)",
  "local FuelRbx = {}",
  "FuelRbx.parentContext = parentContext",
  "",
  "FuelRbx.RootInstance = FuelCore.thing(function(onUpdate, treeOperations)",
  "onUpdate(function(props: { instance: Instance })",
  "    treeOperations.setContext(parentContext, props.instance)",
  "    return nil",
  "end)",
  "return nil",
  "end)",
  "",
  "FuelRbx.InstanceCallback = FuelHooks.statefulComponent(function(hooks, props: { callback: (Instance?) -> () })",
  "local parent = hooks.useContext(parentContext)",
  "hooks.useEffect(function()",
  "    task.spawn(props.callback, parent)",
  "    return",
  "end, { parent, props.callback })",
  "end)",
  "",
  "type Align =",
  '    "TopLeft"',
  '    | "TopRight"',
  '    | "BottomLeft"',
  '    | "BottomRight"',
  '    | "Center"',
  '    | "Top"',
  '    | "Left"',
  '    | "Right"',
  '    | "Bottom"',
  "",
].join("\n"));
console.log(instance("Frame", [
  basicProperty("Name", "name", "string"),
  basicProperty("Size", "size", "UDim2"),
  defaultProperty("BackgroundColor3", "color", "Color3", "Color3.new(1, 1, 1)"),
]));
console.log(instance("TextLabel", [
  basicProperty("Name", "name", "string"),
  defaultProperty("BackgroundColor3", "color", "Color3", "Color3.new(1, 1, 1)"),
  defaultProperty("TextColor3", "textColor", "Color3", "Color3.new(0, 0, 0)"),
  defaultProperty("BorderColor3", "borderColor", "Color3", "Color3.new(0, 0, 0)"),
  defaultProperty("BorderSizePixel", "borderSize", "number", "0"),
  textAlignProp,
  positionProp,
  anchorPointProp,
]));
console.log(instance("TextButton", [
  basicProperty("Name", "name", "string"),
  basicProperty("Text", "text", "string"),
  basicProperty("AutomaticSize", "automaticSize", "Enum.AutomaticSize"),
  defaultProperty("BackgroundColor3", "color", "Color3", "Color3.new(1, 1, 1)"),
  defaultProperty("TextColor3", "textColor", "Color3", "Color3.new(0, 0, 0)"),
  defaultProperty("BorderColor3", "borderColor", "Color3", "Color3.new(0, 0, 0)"),
  defaultProperty("BorderSizePixel", "borderSize", "number", "0"),
  textAlignProp,
  positionProp,
  anchorPointProp,
  callback("Activated", "onActivated"),
]));
console.log(instance("UIListLayout", [
  directionProp,
  alignProp,
]));
console.log(instance("UIPadding", [
  basicProperty("PaddingTop", "top", "UDim"),
  basicProperty("PaddingLeft", "left", "UDim"),
  basicProperty("PaddingRight", "right", "UDim"),
  basicProperty("PaddingBottom", "bottom", "UDim"),
]));
console.log(instance("UICorner", [
  basicProperty("CornerRadius", "radius", "UDim"),
]));
console.log("return FuelRbx");
