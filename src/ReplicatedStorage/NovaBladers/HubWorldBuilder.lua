local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.Color = props.Color or Color3.fromRGB(60, 65, 80)
	part.Size = props.Size
	part.CFrame = props.CFrame
	part.Name = props.Name or "Part"
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = props.Parent
	return part
end

local function addZoneLabel(parent, zone)
	local anchor = Instance.new("Part")
	anchor.Name = "LabelAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(zone.position + Vector3.new(0, 5, 0))
	anchor.Parent = parent

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 70)
	billboard.StudsOffset = Vector3.new(0, 0, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = anchor

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.55, 0)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextScaled = true
	title.Text = zone.name
	title.Parent = billboard

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0, 0.5)
	hint.Size = UDim2.new(1, 0, 0.45, 0)
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(200, 205, 220)
	hint.TextScaled = true
	hint.Text = zone.hint
	hint.Parent = billboard
end

local function addProximityPrompt(zonePart, zone)
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zone.name
	prompt.ObjectText = zone.hint
	prompt.KeyboardKeyCode = zone.promptKey
	prompt.MaxActivationDistance = HubConfig.PROXIMITY_MAX_DISTANCE
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ZoneId", zone.id)
	prompt:SetAttribute("PromptAction", zone.promptAction)
	prompt.Parent = zonePart
end

function HubWorldBuilder.findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = Workspace
		local found = true
		for _, segment in path do
			current = current:FindFirstChild(segment)
			if not current then
				found = false
				break
			end
		end
		if found and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

function HubWorldBuilder.build()
	local existing = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		return existing
	end

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = Workspace

	local floorY = 0
	local floor = makePart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		CFrame = CFrame.new(0, floorY - HubConfig.FLOOR_SIZE.Y / 2, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
		Parent = hub,
	})

	local halfX = HubConfig.FLOOR_SIZE.X / 2
	local halfZ = HubConfig.FLOOR_SIZE.Z / 2
	local wallH = HubConfig.WALL_HEIGHT
	local wallT = HubConfig.WALL_THICKNESS

	local walls = {
		{ Vector3.new(0, wallH / 2, -(halfZ + wallT / 2)), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(0, wallH / 2, halfZ + wallT / 2), Vector3.new(HubConfig.FLOOR_SIZE.X + wallT * 2, wallH, wallT) },
		{ Vector3.new(-(halfX + wallT / 2), wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
		{ Vector3.new(halfX + wallT / 2, wallH / 2, 0), Vector3.new(wallT, wallH, HubConfig.FLOOR_SIZE.Z) },
	}

	for index, wall in walls do
		makePart({
			Name = "Wall" .. index,
			Size = wall[2],
			CFrame = CFrame.new(wall[1]),
			Color = Color3.fromRGB(50, 55, 70),
			Material = Enum.Material.Concrete,
			Parent = hub,
		})
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 0.4
	spawn.BrickColor = BrickColor.new("Bright blue")
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Neutral = true
	spawn.Parent = hub

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = hub

	for _, zone in HubConfig.ZONES do
		local zonePart = makePart({
			Name = zone.id,
			Size = zone.size,
			CFrame = CFrame.new(zone.position),
			Color = zone.color,
			Material = Enum.Material.Neon,
			Parent = zonesFolder,
		})
		zonePart:SetAttribute("ZoneId", zone.id)
		zonePart:SetAttribute("PromptAction", zone.promptAction)
		addZoneLabel(zonePart, zone)
		addProximityPrompt(zonePart, zone)
	end

	local centerSign = makePart({
		Name = "WelcomeSign",
		Size = Vector3.new(10, 6, 0.5),
		CFrame = CFrame.new(0, 4, 18),
		Color = Color3.fromRGB(25, 28, 38),
		Material = Enum.Material.Metal,
		Parent = hub,
	})

	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.Parent = centerSign

	local welcome = Instance.new("TextLabel")
	welcome.BackgroundTransparency = 1
	welcome.Size = UDim2.fromScale(1, 1)
	welcome.Font = Enum.Font.GothamBold
	welcome.TextColor3 = Color3.fromRGB(120, 200, 255)
	welcome.TextScaled = true
	welcome.Text = "NOVA BLADERS\nHub"
	welcome.Parent = surface

	Lighting.Ambient = HubConfig.AMBIENT
	Lighting.OutdoorAmbient = HubConfig.OUTDOOR_AMBIENT
	Lighting.Brightness = HubConfig.CEILING_LIGHT_BRIGHTNESS

	return hub
end

return HubWorldBuilder
