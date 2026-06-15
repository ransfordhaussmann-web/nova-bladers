local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local arenaPlayers = {}
local hubBuilt = false

local function getRemotes()
	return NovaBladers:WaitForChild("Remotes")
end

local function createPart(props)
	local part = Instance.new("Part")
	part.Name = props.Name
	part.Size = props.Size
	part.CFrame = CFrame.new(props.Position)
	part.Anchored = true
	part.CanCollide = props.CanCollide ~= false
	part.Color = props.Color or Color3.fromRGB(60, 65, 80)
	part.Material = props.Material or Enum.Material.SmoothPlastic
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	if props.Transparency then
		part.Transparency = props.Transparency
	end
	return part
end

local function createZoneLabel(parent, title, subtitle)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(200, 60)
	billboard.StudsOffset = Vector3.new(0, 4, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = parent

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Name = "Title"
	titleLabel.Size = UDim2.new(1, 0, 0.55, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.TextScaled = true
	titleLabel.Text = title
	titleLabel.Parent = billboard

	local subLabel = Instance.new("TextLabel")
	subLabel.Name = "Subtitle"
	subLabel.Size = UDim2.new(1, 0, 0.45, 0)
	subLabel.Position = UDim2.fromScale(0, 0.55)
	subLabel.BackgroundTransparency = 1
	subLabel.Font = Enum.Font.Gotham
	subLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	subLabel.TextScaled = true
	subLabel.Text = subtitle
	subLabel.Parent = billboard
end

local function buildBoundaries(hub, platformSize)
	local halfX = platformSize.X / 2
	local halfZ = platformSize.Z / 2
	local height = HubConfig.BOUNDARY_HEIGHT
	local thickness = HubConfig.BOUNDARY_THICKNESS
	local center = HubConfig.PLATFORM_CENTER

	local walls = {
		{ Vector3.new(0, height / 2, -halfZ), Vector3.new(platformSize.X + thickness * 2, height, thickness) },
		{ Vector3.new(0, height / 2, halfZ), Vector3.new(platformSize.X + thickness * 2, height, thickness) },
		{ Vector3.new(-halfX, height / 2, 0), Vector3.new(thickness, height, platformSize.Z) },
		{ Vector3.new(halfX, height / 2, 0), Vector3.new(thickness, height, platformSize.Z) },
	}

	for index, wall in walls do
		local part = createPart({
			Name = "Boundary" .. index,
			Size = wall[2],
			Position = center + wall[1],
			Color = Color3.fromRGB(45, 50, 65),
			Transparency = 0.35,
		})
		part.Parent = hub
	end
end

local function buildDecor(hub)
	local center = HubConfig.PLATFORM_CENTER
	local pedestal = createPart({
		Name = "CentralPedestal",
		Size = Vector3.new(8, 1.5, 8),
		Position = center + Vector3.new(0, 1.75, 0),
		Color = Color3.fromRGB(55, 60, 80),
		Material = Enum.Material.Metal,
	})
	pedestal.Parent = hub

	local core = createPart({
		Name = "NovaCore",
		Size = Vector3.new(3, 3, 3),
		Position = center + Vector3.new(0, 4, 0),
		Color = Color3.fromRGB(100, 160, 255),
		Material = Enum.Material.Neon,
	})
	core.Shape = Enum.PartType.Ball
	core.Parent = hub

	local light = Instance.new("PointLight")
	light.Brightness = 2
	light.Range = 24
	light.Color = Color3.fromRGB(120, 180, 255)
	light.Parent = core

	local ringPositions = {
		Vector3.new(0, 1.1, -18),
		Vector3.new(18, 1.1, 0),
		Vector3.new(0, 1.1, 18),
		Vector3.new(-18, 1.1, 0),
	}
	for index, offset in ringPositions do
		local lamp = createPart({
			Name = "PathLamp" .. index,
			Size = Vector3.new(1.2, 3, 1.2),
			Position = center + offset,
			Color = Color3.fromRGB(70, 75, 95),
			Material = Enum.Material.Metal,
		})
		lamp.Parent = hub

		local glow = Instance.new("PointLight")
		glow.Brightness = 1.2
		glow.Range = 14
		glow.Parent = lamp
	end
end

local function buildZone(hub, zoneConfig, onTriggered)
	local zone = createPart({
		Name = zoneConfig.id,
		Size = zoneConfig.size,
		Position = zoneConfig.position,
		Color = zoneConfig.color,
		Material = Enum.Material.Neon,
	})
	zone.Transparency = 0.25
	zone.Parent = hub

	createZoneLabel(zone, zoneConfig.title, zoneConfig.label)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = zoneConfig.label
	prompt.ObjectText = zoneConfig.title
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.RequiresLineOfSight = false
	prompt.Parent = zone

	prompt.Triggered:Connect(function(player)
		onTriggered(player, zoneConfig.action)
	end)

	return zone
end

function HubWorldManager.getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

function HubWorldManager.isInArena(player)
	return arenaPlayers[player] == true
end

function HubWorldManager.setInArena(player, inArena)
	arenaPlayers[player] = inArena or nil
	player:SetAttribute("InHub", not inArena)
end

function HubWorldManager.getArenaSpawnCFrame()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn")
		if spawn and spawn:IsA("BasePart") then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
		local spawnLocation = arena:FindFirstChildWhichIsA("SpawnLocation", true)
		if spawnLocation then
			return spawnLocation.CFrame + Vector3.new(0, 3, 0)
		end
		local pivot = arena:GetPivot()
		return pivot + Vector3.new(0, 5, 0)
	end
	return CFrame.new(HubConfig.FALLBACK_ARENA_SPAWN)
end

function HubWorldManager.teleportPlayer(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = cframe
end

function HubWorldManager.teleportToHub(player)
	HubWorldManager.setInArena(player, false)
	HubWorldManager.teleportPlayer(player, CFrame.new(HubConfig.SPAWN_POSITION))
end

function HubWorldManager.sendToArena(player)
	HubWorldManager.setInArena(player, true)
	HubWorldManager.teleportPlayer(player, HubWorldManager.getArenaSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	HubWorldManager.fireLobbyReady(player)
end

function HubWorldManager.buildLobbyPayload(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rankPoints)

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = HubWorldManager.getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = not HubWorldManager.isInArena(player),
		forceShowPanel = options.forceShowPanel == true,
	}
end

function HubWorldManager.fireLobbyReady(player, options)
	getRemotes().LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player, options))
end

function HubWorldManager.handleZoneAction(player, action)
	if action == "EnterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "OpenBeySelect" then
		getRemotes().OpenBeySelect:FireClient(player)
	elseif action == "ShowStats" then
		HubWorldManager.fireLobbyReady(player, { forceShowPanel = true })
	end
end

function HubWorldManager.applyLighting()
	Lighting.Brightness = HubConfig.AMBIENT.Brightness
	Lighting.ClockTime = HubConfig.AMBIENT.ClockTime
	Lighting.FogEnd = HubConfig.AMBIENT.FogEnd
	Lighting.FogColor = HubConfig.AMBIENT.FogColor
end

function HubWorldManager.buildWorld()
	if hubBuilt then
		return workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	end

	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubBuilt = true
		return existing
	end

	HubWorldManager.applyLighting()

	local hub = Instance.new("Folder")
	hub.Name = HubConfig.HUB_FOLDER_NAME
	hub.Parent = workspace

	local platform = createPart({
		Name = "HubPlatform",
		Size = HubConfig.PLATFORM_SIZE,
		Position = HubConfig.PLATFORM_CENTER + Vector3.new(0, -1, 0),
		Color = Color3.fromRGB(38, 42, 58),
		Material = Enum.Material.Slate,
	})
	platform.Parent = hub

	local trim = createPart({
		Name = "PlatformTrim",
		Size = HubConfig.PLATFORM_SIZE + Vector3.new(2, 0.4, 2),
		Position = HubConfig.PLATFORM_CENTER + Vector3.new(0, -0.2, 0),
		Color = Color3.fromRGB(90, 120, 200),
		Material = Enum.Material.Neon,
	})
	trim.Parent = hub

	buildBoundaries(hub, HubConfig.PLATFORM_SIZE)
	buildDecor(hub)

	for _, zoneConfig in HubConfig.ZONES do
		buildZone(hub, zoneConfig, function(player, action)
			HubWorldManager.handleZoneAction(player, action)
		end)
	end

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hub

	hubBuilt = true
	return hub
end

function HubWorldManager.onPlayerAdded(player)
	HubWorldManager.setInArena(player, false)

	local function onCharacter(character)
		if HubWorldManager.isInArena(player) then
			return
		end
		task.defer(function()
			HubWorldManager.teleportToHub(player)
			HubWorldManager.fireLobbyReady(player)
		end)
	end

	if player.Character then
		onCharacter(player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

function HubWorldManager.init()
	HubWorldManager.buildWorld()

	local remotes = getRemotes()
	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	if remotes:FindFirstChild("ReturnToHub") then
		remotes.ReturnToHub.OnServerEvent:Connect(function(player)
			HubWorldManager.returnToHub(player)
		end)
	end

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		HubWorldManager.onPlayerAdded(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		HubWorldManager.onPlayerAdded(player)
	end

	Players.PlayerRemoving:Connect(function(player)
		arenaPlayers[player] = nil
		PlayerDataManager.save(player)
	end)
end

return HubWorldManager
