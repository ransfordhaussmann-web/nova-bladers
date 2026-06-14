local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local playerState = {}
local remotes
local hubFolder

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		return HubConfig.ARENA_SPAWN_FALLBACK
	end

	local spawn = arena:FindFirstChild("SpawnLocation", true)
		or arena:FindFirstChild("ArenaSpawn", true)
	if spawn and spawn:IsA("BasePart") then
		return spawn.Position + Vector3.new(0, 3, 0)
	end

	return HubConfig.ARENA_SPAWN_FALLBACK
end

local function teleportPlayer(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function createZoneLabel(part, text)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ZoneLabel"
	billboard.Size = UDim2.fromOffset(220, 48)
	billboard.StudsOffset = Vector3.new(0, part.Size.Y / 2 + 2.5, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = billboard
end

local function createZone(parent, zoneId, config)
	local part = Instance.new("Part")
	part.Name = zoneId
	part.Size = config.size
	part.Position = config.position
	part.Anchored = true
	part.CanCollide = true
	part.Color = config.color
	part.Material = Enum.Material.Neon
	part.Parent = parent

	createZoneLabel(part, config.label)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = config.promptAction
	prompt.ObjectText = config.label
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	return part, prompt
end

local function buildHubWorld()
	if workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME) then
		return workspace[HubConfig.HUB_FOLDER_NAME]
	end

	local folder = Instance.new("Folder")
	folder.Name = HubConfig.HUB_FOLDER_NAME
	folder.Parent = workspace

	local floor = Instance.new("Part")
	floor.Name = "HubFloor"
	floor.Size = HubConfig.FLOOR_SIZE
	floor.Position = HubConfig.FLOOR_POSITION
	floor.Anchored = true
	floor.Color = HubConfig.FLOOR_COLOR
	floor.Material = Enum.Material.Slate
	floor.Parent = folder

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(6, 1, 6)
	spawn.Position = HubConfig.SPAWN_POSITION
	spawn.Anchored = true
	spawn.CanCollide = false
	spawn.Neutral = true
	spawn.Transparency = 1
	spawn.Parent = folder

	local zonesFolder = Instance.new("Folder")
	zonesFolder.Name = "Zones"
	zonesFolder.Parent = folder

	for zoneId, config in HubConfig.ZONES do
		createZone(zonesFolder, zoneId, config)
	end

	return folder
end

local function connectZonePrompts()
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	local arenaPrompt = zones.ArenaGate:FindFirstChildOfClass("ProximityPrompt")
	if arenaPrompt then
		arenaPrompt.Triggered:Connect(function(player)
			HubWorldManager.sendToArena(player)
		end)
	end

	local shopPrompt = zones.BeyShop:FindFirstChildOfClass("ProximityPrompt")
	if shopPrompt then
		shopPrompt.Triggered:Connect(function(player)
			remotes.OpenBeySelect:FireClient(player)
		end)
	end

	local statsPrompt = zones.StatsBoard:FindFirstChildOfClass("ProximityPrompt")
	if statsPrompt then
		statsPrompt.Triggered:Connect(function(player)
			HubWorldManager.pushLobbyState(player)
		end)
	end
end

function HubWorldManager.isInArena(player)
	return playerState[player] == "arena"
end

function HubWorldManager.pushLobbyState(player)
	local data = PlayerDataManager.get(player)
	local rank = PlayerDataManager.getRankPoints(data)
	LeaderboardManager.submit(player, rank)

	remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		hubMode = playerState[player] ~= "arena",
	})

	remotes.HubState:FireClient(player, {
		inHub = playerState[player] == "hub",
		inArena = playerState[player] == "arena",
	})
end

function HubWorldManager.sendToArena(player)
	playerState[player] = "arena"
	teleportPlayer(player, findArenaSpawn())
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.returnToHub(player)
	playerState[player] = "hub"
	teleportPlayer(player, HubConfig.SPAWN_POSITION)
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.onPlayerAdded(player)
	playerState[player] = "hub"

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if playerState[player] == "hub" then
			teleportPlayer(player, HubConfig.SPAWN_POSITION)
		elseif playerState[player] == "arena" then
			teleportPlayer(player, findArenaSpawn())
		end
	end)

	PlayerDataManager.load(player)
	HubWorldManager.pushLobbyState(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubFolder = buildHubWorld()
	connectZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.sendToArena(player)
	end)

	remotes.RefreshHubStats.OnServerEvent:Connect(function(player)
		HubWorldManager.pushLobbyState(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerState[player] = nil
	end)
end

return HubWorldManager
