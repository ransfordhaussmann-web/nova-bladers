local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local HubWorldBuilder = {}

local function anchor(part)
	part.Anchored = true
	part.CanCollide = true
	return part
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Name = props.Name or "Part"
	part.Size = props.Size or Vector3.new(4, 1, 4)
	part.Position = props.Position or Vector3.new(0, 0, 0)
	part.Color = props.Color or Color3.fromRGB(200, 200, 200)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Transparency = props.Transparency or 0
	part.Shape = props.Shape
	anchor(part)
	if props.Parent then
		part.Parent = props.Parent
	end
	return part
end

local function addZoneLabel(parent, zoneId, zone)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.new(0, zone.size.Y * 0.75, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0.4
	title.Text = zone.name
	title.Parent = billboard

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, 0, 0.45, 0)
	hint.Position = UDim2.fromScale(0, 0.55)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(220, 220, 220)
	hint.TextStrokeTransparency = 0.5
	hint.Text = zone.hint
	hint.Parent = billboard
end

local function addProximityPrompt(parent, zoneId, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zone.hint
	prompt.ObjectText = zone.name
	prompt.MaxActivationDistance = HubConfig.PROMPT_DISTANCE
	prompt.HoldDuration = HubConfig.PROMPT_HOLD
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zoneId)
	prompt:SetAttribute("ZoneAction", zone.action)
	prompt.Parent = parent
end

function HubWorldBuilder.configureLighting()
	Lighting.ClockTime = 15.5
	Lighting.Brightness = 2.2
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
end

function HubWorldBuilder.build()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	HubWorldBuilder.configureLighting()

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = Workspace

	local origin = HubConfig.HUB_ORIGIN

	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = origin + Vector3.new(0, -0.5, 0),
		Color = Color3.fromRGB(45, 50, 65),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local ring = makePart({
		Name = "CenterRing",
		Size = Vector3.new(24, 0.4, 24),
		Position = origin + Vector3.new(0, 0.2, 0),
		Color = Color3.fromRGB(90, 120, 200),
		Material = Enum.Material.Neon,
		Transparency = 0.15,
		Shape = Enum.PartType.Cylinder,
		Parent = hub,
	})
	ring.Orientation = Vector3.new(0, 0, 90)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = origin + HubConfig.SPAWN_OFFSET
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for zoneId, zone in HubConfig.ZONES do
		local pedestal = makePart({
			Name = zoneId,
			Size = zone.size,
			Position = origin + zone.position,
			Color = zone.color,
			Material = Enum.Material.Metal,
			Parent = zonesFolder,
		})

		local glow = makePart({
			Name = "Glow",
			Size = Vector3.new(zone.size.X + 1, 0.3, zone.size.Z + 1),
			Position = origin + zone.position - Vector3.new(0, zone.size.Y * 0.5 - 0.15, 0),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Transparency = 0.35,
			Parent = pedestal,
		})

		local light = Instance.new("PointLight")
		light.Color = zone.color
		light.Brightness = 1.5
		light.Range = 18
		light.Parent = pedestal

		addZoneLabel(pedestal, zoneId, zone)
		addProximityPrompt(pedestal, zoneId, zone)
	end

	local pathColor = Color3.fromRGB(70, 75, 90)
	for _, offset in {
		Vector3.new(0, 0.15, -20),
		Vector3.new(-20, 0.15, 0),
		Vector3.new(20, 0.15, 0),
	} do
		makePart({
			Name = "Path",
			Size = Vector3.new(6, 0.3, 30),
			Position = origin + offset,
			Color = pathColor,
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local sign = makePart({
		Name = "WelcomeSign",
		Size = Vector3.new(18, 6, 1),
		Position = origin + Vector3.new(0, 5, 52),
		Color = Color3.fromRGB(30, 35, 50),
		Material = Enum.Material.SmoothPlastic,
		Parent = hub,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = sign

	local welcome = Instance.new("TextLabel")
	welcome.Size = UDim2.fromScale(1, 1)
	welcome.BackgroundTransparency = 1
	welcome.Font = Enum.Font.GothamBold
	welcome.TextSize = 28
	welcome.TextColor3 = Color3.fromRGB(180, 210, 255)
	welcome.Text = "Nova Bladers Hub"
	welcome.Parent = surface

	return hub
end

function HubWorldBuilder.getSpawnCFrame()
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
end

function HubWorldBuilder.getArenaSpawnCFrame()
	local arena = Workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild(HubConfig.ARENA_SPAWN_NAME, true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.HUB_ORIGIN + Vector3.new(0, 10, -120))
end

return HubWorldBuilder
