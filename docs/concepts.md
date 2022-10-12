# Concepts

## Resources

Resources represent something that can be controlled by Fuel. Resource definitions define how a
resource is created, updated, and destroyed. Fuel comes with a variety of resource definitions for
Roblox instances. Resources can take properties that are used when creating and updating the object
the resource represents. Whenever properties change, Fuel will update the resource with the new
properties.

## Elements

Elements represent how a tree of resources should look at any given state of time. An element
consists of properties and child elements. Resource definitions provide a function that's used for
creating an element for that resource.

## Apply

Applying takes a tree of resources and a tree of elements and creates resources, updates existing
resources, or destroys resources to match the elements.

## Context

Context is data that gets propagated down the tree. Resources can interact with context at any time
to pass data down the tree or subscribe to context.
