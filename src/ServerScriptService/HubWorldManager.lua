local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local ServerScriptService = game:GetService("ServerScriptService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LeaderboardManager = require(ServerScriptService.LeaderboardManager)

local HubWorldManager = {}

local hubFolder = nil
local arenaPlayers = {}
local initialized = false

local function getRemotes()
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	return nova:WaitForChild("Remotes")
end

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

local function createSign(parent, text, position, color)
	local sign = createPart({
		Name = "Sign",
		Size = Vector3.new(10, 4, 0.5),
		Position = position,
		Color = color,
		Material = Enum.Material.SmoothPlastic,
		Parent = parent,
	})

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.Parent = sign

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return sign
end

local function createZone(parent, zoneConfig)
	local zone = createPart({
		Name = zoneConfig.id,
		Size = zoneConfig.size,
		Position = zoneConfig.position,
		Color = zoneConfig.color,
		Material = Enum.Material.Neon,
		Transparency = 0.35,
		CanCollide = true,
		Parent = parent,
	})
	zone:SetAttribute("ZoneId", zoneConfig.id)
	zone:SetAttribute("PromptAction", zoneConfig.promptAction)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zoneConfig.label
	prompt.ObjectText = zoneConfig.hint
	prompt.MaxActivationDistance = 12
	prompt.HoldDuration = 0
	prompt.Parent = zone

	local signPos = zoneConfig.position + Vector3.new(0, 5, -zoneConfig.size.Z / 2 - 1)
	createSign(parent, zoneConfig.label, signPos, zoneConfig.color)

	return zone
end

local function buildHubWorld()
	if hubFolder then
		return hubFolder
	end

	local existing = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if existing then
		hubFolder = existing
		return hubFolder
	end

	hubFolder = Instance.new("Folder")
	hubFolder.Name = HubConfig.HUB_FOLDER_NAME
	hubFolder.Parent = workspace

	local floor = createPart({
		Name = "Floor",
		Size = HubConfig.FLOOR_SIZE,
		Position = Vector3.new(0, 0, 0),
		Color = Color3.fromRGB(35, 38, 48),
		Material = Enum.Material.Slate,
		Parent = hubFolder,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Transparency = 1
	spawn.Duration = 0
	spawn.Neutral = true
	spawn.Parent = hubFolder

	-- Decorative boundary pillars
	local half = HubConfig.FLOOR_SIZE.X / 2 - 2
	for _, offset in { Vector3.new(half, 3, half), Vector3.new(-half, 3, half),
		Vector3.new(half, 3, -half), Vector3.new(-half, 3, -half) } do
		createPart({
			Name = "Pillar",
			Size = Vector3.new(3, 6, 3),
			Position = offset,
			Color = Color3.fromRGB(60, 65, 80),
			Material = Enum.Material.Concrete,
			Parent = hubFolder,
		})
	end

	createPart({
		Name = "CenterLogo",
		Size = Vector3.new(12, 0.4, 12),
		Position = Vector3.new(0, 1.2, 0),
		Color = Color3.fromRGB(120, 80, 255),
		Material = Enum.Material.Neon,
		Transparency = 0.5,
		Parent = hubFolder,
	})

	for _, zoneConfig in HubConfig.ZONES do
		createZone(hubFolder, zoneConfig)
	end

	-- Hub lighting
	local hubLight = Instance.new("PointLight")
	hubLight.Brightness = 1.2
	hubLight.Range = 80
	hubLight.Color = Color3.fromRGB(200, 210, 255)
	hubLight.Parent = floor

	return hubFolder
end

local function setHubLighting()
	Lighting.ClockTime = 17.5
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(70, 75, 90)
	Lighting.OutdoorAmbient = Color3.fromRGB(90, 95, 110)
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function getArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if arena then
		local spawn = arena:FindFirstChild("Spawn", true)
		if spawn and spawn:IsA("BasePart") then
			return spawn.Position + HubConfig.ARENA_SPAWN_OFFSET
		end
		if arena:IsA("BasePart") then
			return arena.Position + HubConfig.ARENA_SPAWN_OFFSET
		end
	end
	return HubConfig.SPAWN_POSITION + Vector3.new(0, 20, -60)
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = "Modus: Training",
		leaderboard = LeaderboardManager.getTop(5),
		inHub = true,
		showPanel = true,
	}
end

local function broadcastHubState(player, inHub)
	local remotes = getRemotes()
	local hubState = remotes:FindFirstChild("HubState")
	if hubState then
		hubState:FireClient(player, { inHub = inHub })
	end
end

function HubWorldManager.isInArena(player)
	return arenaPlayers[player] == true
end

function HubWorldManager.sendToArena(player)
	arenaPlayers[player] = true
	teleportCharacter(player, getArenaSpawn())
	broadcastHubState(player, false)

	local request = ServerScriptService:FindFirstChild("ArenaEntryRequest")
	if not request then
		request = Instance.new("BindableEvent")
		request.Name = "ArenaEntryRequest"
		request.Parent = ServerScriptService
	end
	request:Fire(player)
end

function HubWorldManager.returnToHub(player)
	arenaPlayers[player] = nil
	local returnPos = HubConfig.SPAWN_POSITION + HubConfig.RETURN_SPAWN_OFFSET
	teleportCharacter(player, returnPos)
	broadcastHubState(player, true)
end

local function onZonePromptTriggered(player, zone)
	local action = zone:GetAttribute("PromptAction")
	if not action then return end

	local remotes = getRemotes()

	if action == "EnterArena" then
		HubWorldManager.sendToArena(player)
	elseif action == "OpenBeySelect" then
		local openBey = remotes:FindFirstChild("OpenBeySelect")
		if openBey then
			openBey:FireClient(player)
		end
	elseif action == "ShowLobbyStats" then
		local lobbyReady = remotes:FindFirstChild("LobbyReady")
		if lobbyReady then
			lobbyReady:FireClient(player, buildLobbyPayload(player))
		end
	end
end

local function bindZonePrompts()
	for _, child in hubFolder:GetChildren() do
		if child:GetAttribute("ZoneId") then
			local prompt = child:FindFirstChild("ZonePrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					onZonePromptTriggered(player, child)
				end)
			end
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if not HubWorldManager.isInArena(player) then
			teleportCharacter(player, HubConfig.SPAWN_POSITION)
			broadcastHubState(player, true)
		end
	end)
end

function HubWorldManager.init()
	if initialized then return end
	initialized = true

	buildHubWorld()
	setHubLighting()
	bindZonePrompts()

	Players.PlayerRemoving:Connect(function(player)
		arenaPlayers[player] = nil
	end)
end

return HubWorldManager
