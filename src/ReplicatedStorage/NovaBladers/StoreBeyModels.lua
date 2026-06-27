local BeyCatalog = require(script.Parent.BeyCatalog)

local StoreBeyModels = {}

local MODELS = {
	NovaStriker = {
		coreSize = Vector3.new(1.6, 0.5, 1.6),
		ringSize = Vector3.new(2.4, 0.35, 2.4),
		accentSize = Vector3.new(0.4, 0.8, 0.4),
		coreColor = Color3.fromRGB(60, 110, 255),
		ringColor = Color3.fromRGB(120, 180, 255),
		accentColor = Color3.fromRGB(200, 230, 255),
	},
	IronShell = {
		coreSize = Vector3.new(1.8, 0.6, 1.8),
		ringSize = Vector3.new(2.6, 0.5, 2.6),
		accentSize = Vector3.new(0.5, 0.4, 0.5),
		coreColor = Color3.fromRGB(50, 120, 70),
		ringColor = Color3.fromRGB(90, 180, 110),
		accentColor = Color3.fromRGB(140, 220, 160),
	},
	VoltDash = {
		coreSize = Vector3.new(1.5, 0.45, 1.5),
		ringSize = Vector3.new(2.2, 0.3, 2.2),
		accentSize = Vector3.new(0.35, 0.9, 0.35),
		coreColor = Color3.fromRGB(255, 180, 40),
		ringColor = Color3.fromRGB(255, 220, 80),
		accentColor = Color3.fromRGB(255, 255, 180),
	},
	ShadowBite = {
		coreSize = Vector3.new(1.55, 0.5, 1.55),
		ringSize = Vector3.new(2.3, 0.35, 2.3),
		accentSize = Vector3.new(0.45, 0.7, 0.45),
		coreColor = Color3.fromRGB(100, 50, 180),
		ringColor = Color3.fromRGB(140, 80, 220),
		accentColor = Color3.fromRGB(200, 150, 255),
	},
	CrimsonVortex = {
		coreSize = Vector3.new(1.5, 0.55, 1.5),
		ringSize = Vector3.new(2.5, 0.4, 2.5),
		accentSize = Vector3.new(0.5, 0.6, 0.5),
		coreColor = Color3.fromRGB(180, 30, 45),
		ringColor = Color3.fromRGB(220, 55, 70),
		accentColor = Color3.fromRGB(255, 120, 130),
	},
	FrostRing = {
		coreSize = Vector3.new(1.9, 0.65, 1.9),
		ringSize = Vector3.new(2.8, 0.55, 2.8),
		accentSize = Vector3.new(0.55, 0.35, 0.55),
		coreColor = Color3.fromRGB(100, 180, 230),
		ringColor = Color3.fromRGB(150, 215, 255),
		accentColor = Color3.fromRGB(220, 245, 255),
	},
}

function StoreBeyModels.getDefinition(beyId)
	return MODELS[beyId]
end

function StoreBeyModels.getStoreItems()
	local items = {}
	for _, bey in BeyCatalog do
		if bey.storeItem then
			table.insert(items, bey)
		end
	end
	return items
end

function StoreBeyModels.build(beyId, parent)
	local def = MODELS[beyId]
	if not def then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = beyId

	local core = Instance.new("Part")
	core.Name = "Core"
	core.Size = def.coreSize
	core.Color = def.coreColor
	core.Material = Enum.Material.Metal
	core.Anchored = true
	core.CanCollide = false
	core.Parent = model

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Size = def.ringSize
	ring.Color = def.ringColor
	ring.Material = Enum.Material.Neon
	ring.Transparency = 0.15
	ring.Anchored = true
	ring.CanCollide = false
	ring.Parent = model

	local accent = Instance.new("Part")
	accent.Name = "Accent"
	accent.Size = def.accentSize
	accent.Color = def.accentColor
	accent.Material = Enum.Material.Glass
	accent.Anchored = true
	accent.CanCollide = false
	accent.Parent = model

	ring.CFrame = core.CFrame
	accent.CFrame = core.CFrame * CFrame.new(0, def.coreSize.Y / 2 + def.accentSize.Y / 2, 0)

	model.PrimaryPart = core
	model.Parent = parent
	return model
end

return StoreBeyModels
