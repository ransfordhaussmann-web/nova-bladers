local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function createPart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in props do
		part[key] = value
	end
	return part
end

local function createLabel(parent, text, offsetY)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "Label"
	billboard.Size = UDim2.fromOffset(200, 50)
	billboard.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.5
	label.TextSize = 18
	label.Text = text
	label.Parent = billboard
end

local function createZone(parent, zoneId, zone)
	local model = Instance.new("Model")
	model.Name = zoneId

	local platform = createPart({
		Name = "Platform",
		Size = zone.size,
		Position = zone.position,
		Color = zone.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = true,
	})
	platform.Parent = model

	local promptPart = createPart({
		Name = "PromptAnchor",
		Size = Vector3.new(4, 4, 4),
		Position = zone.position + Vector3.new(0, zone.size.Y * 0.5 + 2, 0),
		Transparency = 1,
		CanCollide = false,
	})
	promptPart.Parent = model

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.promptText
	prompt.ObjectText = zone.label
	prompt.HoldDuration = HubConfig.PROMPT_HOLD
	prompt.MaxActivationDistance = HubConfig.PROMPT_DISTANCE
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("HubAction", zone.action)
	prompt.Parent = promptPart

	createLabel(promptPart, zone.label, 2)
	model.Parent = parent
	return model
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME

	local floor = createPart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = HubConfig.FLOOR_COLOR,
		Material = Enum.Material.Slate,
	})
	floor.Parent = hub

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.HUB_SPAWN_OFFSET
	spawn.Color = HubConfig.ACCENT_COLOR
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.4
	spawn.Neutral = true
	spawn.AllowTeamChangeOnTouch = false
	spawn.Duration = 0
	spawn.Parent = hub

	local rimOffsets = {
		Vector3.new(0, 2, HubConfig.FLOOR_SIZE.Z * 0.5),
		Vector3.new(0, 2, -HubConfig.FLOOR_SIZE.Z * 0.5),
		Vector3.new(HubConfig.FLOOR_SIZE.X * 0.5, 2, 0),
		Vector3.new(-HubConfig.FLOOR_SIZE.X * 0.5, 2, 0),
	}
	for index, offset in rimOffsets do
		local wall = createPart({
			Name = "Rim_" .. index,
			Size = if math.abs(offset.X) > 0
				then Vector3.new(2, 4, HubConfig.FLOOR_SIZE.Z)
				else Vector3.new(HubConfig.FLOOR_SIZE.X, 4, 2),
			Position = offset,
			Color = Color3.fromRGB(18, 20, 30),
			Material = Enum.Material.Metal,
		})
		wall.Parent = hub
	end

	local beacon = createPart({
		Name = "CenterBeacon",
		Size = Vector3.new(3, 12, 3),
		Position = Vector3.new(0, 6, 0),
		Color = HubConfig.ACCENT_COLOR,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
	})
	beacon.Parent = hub

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 30
	light.Color = HubConfig.ACCENT_COLOR
	light.Parent = beacon

	local zones = Instance.new("Folder")
	zones.Name = "Zones"
	zones.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		createZone(zones, zoneId, zone)
	end

	hub.Parent = workspace
	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	local spawn = hub and hub:FindFirstChild("HubSpawn")
	if spawn and spawn:IsA("BasePart") then
		return spawn.CFrame + Vector3.new(0, 3, 0)
	end
	return CFrame.new(HubConfig.HUB_SPAWN_OFFSET)
end

function HubWorldBuilder.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local marker = arena:FindFirstChild("Spawn", true)
		if marker and marker:IsA("BasePart") then
			return marker.CFrame + Vector3.new(0, 3, 0)
		end
		if arena:IsA("BasePart") then
			return arena.CFrame + Vector3.new(0, 3, 0)
		end
		local part = arena:FindFirstChildWhichIsA("BasePart", true)
		if part then
			return part.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.ARENA_SPAWN_OFFSET)
end

return HubWorldBuilder
