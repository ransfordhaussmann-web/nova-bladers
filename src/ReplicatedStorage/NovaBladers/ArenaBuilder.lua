local BeyConfig = require(script.Parent.BeyConfig)

local ArenaBuilder = {}

function ArenaBuilder.build()
	local existing = workspace:FindFirstChild("Arena")
	if existing then
		existing:Destroy()
	end

	local arena = Instance.new("Folder")
	arena.Name = "Arena"
	arena.Parent = workspace

	local radius = BeyConfig.ARENA_RADIUS
	local origin = Vector3.new(0, 2, 200)

	local floor = Instance.new("Part")
	floor.Name = "Floor"
	floor.Anchored = true
	floor.Size = Vector3.new(radius * 2.2, 1, radius * 2.2)
	floor.CFrame = CFrame.new(origin - Vector3.new(0, 0.5, 0))
	floor.Color = Color3.fromRGB(30, 35, 48)
	floor.Material = Enum.Material.Slate
	floor.Parent = arena

	local bowl = Instance.new("Part")
	bowl.Name = "Bowl"
	bowl.Anchored = true
	bowl.Shape = Enum.PartType.Cylinder
	bowl.Size = Vector3.new(0.8, radius * 2, radius * 2)
	bowl.CFrame = CFrame.new(origin + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	bowl.Color = Color3.fromRGB(45, 55, 75)
	bowl.Material = Enum.Material.SmoothPlastic
	bowl.Transparency = 0.15
	bowl.Parent = arena

	local rim = Instance.new("Part")
	rim.Name = "Rim"
	rim.Anchored = true
	rim.Shape = Enum.PartType.Cylinder
	rim.Size = Vector3.new(1.2, radius * 2 + 4, radius * 2 + 4)
	rim.CFrame = CFrame.new(origin + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90))
	rim.Color = Color3.fromRGB(80, 140, 255)
	rim.Material = Enum.Material.Neon
	rim.Transparency = 0.4
	rim.Parent = arena

	local spawnPoints = {}
	local count = 8
	for i = 1, count do
		local angle = (i - 1) * (math.pi * 2 / count)
		local dist = radius * 0.55
		local pos = origin + Vector3.new(math.cos(angle) * dist, 1.5, math.sin(angle) * dist)
		spawnPoints[i] = CFrame.new(pos)
	end

	return {
		folder = arena,
		origin = origin,
		radius = radius,
		spawnPoints = spawnPoints,
	}
end

function ArenaBuilder.hide()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		arena.Parent = nil
	end
end

function ArenaBuilder.show()
	local arena = workspace:FindFirstChild("Arena")
	if not arena then
		return ArenaBuilder.build()
	end
	arena.Parent = workspace
	return {
		folder = arena,
		origin = Vector3.new(0, 2, 200),
		radius = BeyConfig.ARENA_RADIUS,
		spawnPoints = {},
	}
end

return ArenaBuilder
