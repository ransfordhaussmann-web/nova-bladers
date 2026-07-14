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
	local outerRadius = BeyConfig.OUTER_PLATFORM_RADIUS
	local origin = Vector3.new(0, 2, 200)
	local platformY = origin.Y + BeyConfig.OUTER_PLATFORM_Y

	local function makePart(props)
		local part = Instance.new("Part")
		part.Anchored = true
		part.Name = props.Name
		part.Size = props.Size
		part.CFrame = props.CFrame
		part.Color = props.Color or Color3.fromRGB(45, 55, 75)
		part.Material = props.Material or Enum.Material.SmoothPlastic
		part.Transparency = props.Transparency or 0
		part.CanCollide = props.CanCollide ~= false
		part.Parent = arena
		return part
	end

	-- Base floor under entire zone
	makePart({
		Name = "Floor",
		Size = Vector3.new(outerRadius * 2.2, 1, outerRadius * 2.2),
		CFrame = CFrame.new(origin - Vector3.new(0, 0.5, 0)),
		Color = Color3.fromRGB(30, 35, 48),
		Material = Enum.Material.Slate,
	})

	-- Bowl floor (inner stadium)
	makePart({
		Name = "BowlFloor",
		Size = Vector3.new(radius * 1.8, 0.4, radius * 1.8),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.2, 0)),
		Color = Color3.fromRGB(40, 48, 62),
		Material = Enum.Material.Slate,
	})

	-- Bowl visual ring
	local bowl = makePart({
		Name = "Bowl",
		Size = Vector3.new(0.8, radius * 2, radius * 2),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(45, 55, 75),
		Transparency = 0.15,
	})
	bowl.Shape = Enum.PartType.Cylinder

	-- Neon rim — jump over this to leave the bowl
	local rim = makePart({
		Name = "Rim",
		Size = Vector3.new(1.2, radius * 2 + 4, radius * 2 + 4),
		CFrame = CFrame.new(origin + Vector3.new(0, 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Color = Color3.fromRGB(80, 140, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	rim.Shape = Enum.PartType.Cylinder

	-- Outer elevated platform ring (fight outside the bowl)
	for i = 1, 8 do
		local angle = (i - 1) * (math.pi / 4)
		local midRadius = (radius + outerRadius) / 2
		local segLen = (outerRadius - radius) * 0.9
		local pos = origin + Vector3.new(math.cos(angle) * midRadius, platformY - origin.Y, math.sin(angle) * midRadius)
		makePart({
			Name = "OuterPlatform_" .. i,
			Size = Vector3.new(segLen, 1, 10),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, -angle, 0),
			Color = Color3.fromRGB(55, 62, 80),
			Material = Enum.Material.Metal,
		})
	end

	-- Sky zone marker (visual hint for aerial combat)
	makePart({
		Name = "SkyMarker",
		Size = Vector3.new(outerRadius * 2, 0.2, outerRadius * 2),
		CFrame = CFrame.new(origin + Vector3.new(0, 22, 0)),
		Color = Color3.fromRGB(100, 160, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.85,
		CanCollide = false,
	})

	local spawnPoints = {}
	local count = 8
	for i = 1, count do
		local angle = (i - 1) * (math.pi * 2 / count)
		local dist = radius * 0.55
		local pos = origin + Vector3.new(math.cos(angle) * dist, BeyConfig.BOWL_FLOOR_OFFSET, math.sin(angle) * dist)
		spawnPoints[i] = CFrame.new(pos)
	end

	return {
		folder = arena,
		origin = origin,
		radius = radius,
		outerRadius = outerRadius,
		platformY = platformY,
		floorY = origin.Y + BeyConfig.BOWL_FLOOR_OFFSET,
		spawnPoints = spawnPoints,
	}
end

function ArenaBuilder.hide()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		arena.Parent = nil
	end
end

return ArenaBuilder
