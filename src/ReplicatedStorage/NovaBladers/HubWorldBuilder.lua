local HubConfig = require(script.Parent.HubConfig)

local HubWorldBuilder = {}

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	part.CanCollide = props.canCollide ~= false
	part.CastShadow = props.castShadow ~= false
	part.Name = props.name or "Part"
	part.Size = props.size or Vector3.new(4, 4, 4)
	part.CFrame = props.cframe or CFrame.new(props.position or HubConfig.ORIGIN)
	part.Color = props.color or Color3.fromRGB(200, 200, 200)
	part.Material = props.material or Enum.Material.SmoothPlastic
	part.Transparency = props.transparency or 0
	part.Parent = props.parent
	return part
end

local function addSign(parent, text, offset, color)
	local sign = makePart({
		name = "Sign",
		parent = parent,
		size = Vector3.new(8, 3, 0.4),
		cframe = parent.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.rad(180), 0),
		color = HubConfig.COLORS.sign,
		material = Enum.Material.Neon,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(30, 30, 40)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
end

local function buildZoneStructure(hub, zoneKey, zoneDef, color)
	local origin = HubConfig.ORIGIN + zoneDef.position
	local folder = Instance.new("Folder")
	folder.Name = zoneKey
	folder.Parent = hub

	local base = makePart({
		name = "Base",
		parent = folder,
		size = Vector3.new(zoneDef.size.X, 1, zoneDef.size.Z),
		position = origin + Vector3.new(0, 0.5, 0),
		color = HubConfig.COLORS.floorAccent,
		material = Enum.Material.Slate,
	})

	local buildingHeight = zoneDef.size.Y
	makePart({
		name = "Structure",
		parent = folder,
		size = Vector3.new(zoneDef.size.X - 2, buildingHeight, zoneDef.size.Z - 2),
		position = origin + Vector3.new(0, buildingHeight / 2 + 1, 0),
		color = color,
		material = Enum.Material.Metal,
	})

	local trigger = makePart({
		name = "ZoneTrigger",
		parent = folder,
		size = Vector3.new(zoneDef.size.X, zoneDef.size.Y + 4, zoneDef.size.Z),
		position = origin + Vector3.new(0, (zoneDef.size.Y + 4) / 2, 0),
		transparency = 1,
		canCollide = false,
		castShadow = false,
	})
	trigger:SetAttribute("ZoneId", zoneDef.id)

	local promptPart = makePart({
		name = "PromptAnchor",
		parent = folder,
		size = Vector3.new(2, 2, 2),
		position = origin + Vector3.new(0, 2, zoneDef.size.Z / 2 + 1),
		transparency = 1,
		canCollide = false,
		castShadow = false,
	})

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = zoneDef.prompt
	prompt.ObjectText = zoneDef.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.Parent = promptPart
	prompt:SetAttribute("ZoneAction", zoneDef.action)

	addSign(base, zoneDef.label, Vector3.new(0, buildingHeight + 2, -(zoneDef.size.Z / 2 + 0.5)), color)

	return folder, trigger, prompt
end

function HubWorldBuilder.build()
	local existing = workspace:FindFirstChild("NovaHub")
	if existing then
		existing:Destroy()
	end

	local hub = Instance.new("Folder")
	hub.Name = "NovaHub"
	hub.Parent = workspace

	local floor = makePart({
		name = "Floor",
		parent = hub,
		size = HubConfig.FLOOR_SIZE,
		position = HubConfig.ORIGIN + Vector3.new(0, 0.5, 0),
		color = HubConfig.COLORS.floor,
		material = Enum.Material.Concrete,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.HUB_SPAWN)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Neutral = true
	spawn.Parent = hub

	local centerPad = makePart({
		name = "CenterPad",
		parent = hub,
		size = Vector3.new(20, 0.4, 20),
		position = HubConfig.ORIGIN + Vector3.new(0, 1.2, 0),
		color = HubConfig.COLORS.arenaGate,
		material = Enum.Material.Neon,
	})
	centerPad.Transparency = 0.35

	local zones = {}
	for zoneKey, zoneDef in HubConfig.ZONES do
		local color = HubConfig.COLORS.arenaGate
		if zoneKey == "BeyLab" then
			color = HubConfig.COLORS.beyLab
		elseif zoneKey == "HallOfFame" then
			color = HubConfig.COLORS.hallOfFame
		end
		local folder, trigger, prompt = buildZoneStructure(hub, zoneKey, zoneDef, color)
		zones[zoneDef.id] = {
			folder = folder,
			trigger = trigger,
			prompt = prompt,
			def = zoneDef,
		}
	end

	local gateFolder = zones.ArenaGate.folder
	local gateGlow = makePart({
		name = "GateGlow",
		parent = gateFolder,
		size = Vector3.new(8, 8, 0.6),
		position = HubConfig.ORIGIN + HubConfig.ZONES.ArenaGate.position + Vector3.new(0, 6, HubConfig.ZONES.ArenaGate.size.Z / 2 + 0.5),
		color = HubConfig.COLORS.arenaGate,
		material = Enum.Material.Neon,
	})
	gateGlow.Transparency = 0.25
	gateGlow:SetAttribute("PulseGlow", true)

	local board = makePart({
		name = "LeaderboardBoard",
		parent = zones.HallOfFame.folder,
		size = Vector3.new(10, 6, 0.5),
		position = HubConfig.ORIGIN + HubConfig.ZONES.HallOfFame.position + Vector3.new(0, 5, HubConfig.ZONES.HallOfFame.size.Z / 2 + 0.5),
		color = HubConfig.COLORS.hallOfFame,
		material = Enum.Material.SmoothPlastic,
	})

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Front
	boardGui.Parent = board

	local boardLabel = Instance.new("TextLabel")
	boardLabel.Name = "BoardText"
	boardLabel.Size = UDim2.fromScale(1, 1)
	boardLabel.BackgroundTransparency = 1
	boardLabel.Text = "🏆 Ruhmeshalle\nBetrete die Zone für Stats"
	boardLabel.TextColor3 = Color3.fromRGB(30, 25, 15)
	boardLabel.TextScaled = true
	boardLabel.Font = Enum.Font.GothamMedium
	boardLabel.Parent = boardGui

	return {
		hub = hub,
		floor = floor,
		spawn = spawn,
		zones = zones,
		leaderboardBoard = boardLabel,
	}
end

return HubWorldBuilder
