local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local zonesByAction = {}
local inArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local function findArenaSpawn()
	local spawn = workspace:FindFirstChild("ArenaSpawn")
	if spawn then
		return spawn
	end
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		return arena:FindFirstChild("ArenaSpawn")
	end
	return nil
end

local function teleportCharacter(player, position)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = CFrame.new(position)
	end
end

local function getHubSpawnCFrame()
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		local spawn = hub:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

function HubWorldManager.sendLobbyPayload(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.teleportToHub(player)
	inArena[player] = nil
	teleportCharacter(player, getHubSpawnCFrame().Position)
	remotes.ReturnToHub:FireClient(player)
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
end

local function enterArena(player)
	inArena[player] = true
	local spawn = findArenaSpawn()
	local position = HubConfig.ARENA_FALLBACK_POSITION
	if spawn then
		if spawn:IsA("BasePart") then
			position = spawn.Position + Vector3.new(0, 3, 0)
		elseif spawn:IsA("Attachment") then
			position = spawn.WorldPosition
		end
	end
	teleportCharacter(player, position)
end

local function onZoneAction(player, action)
	if action == "EnterArena" then
		enterArena(player)
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowHallPanel" then
		HubWorldManager.sendLobbyPayload(player)
		remotes.ShowHallPanel:FireClient(player, buildLobbyPayload(player))
	end
end

local function connectZonePrompts(zones)
	for _, zone in zones do
		zonesByAction[zone.action] = zone
		zone.prompt.Triggered:Connect(function(player)
			onZoneAction(player, zone.action)
		end)
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if not inArena[player] then
			HubWorldManager.teleportToHub(player)
		end
	end)

	if player.Character then
		HubWorldManager.teleportToHub(player)
	end
end

local function onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.setup()
	local _, zones = HubWorldBuilder.build()
	connectZonePrompts(zones)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if typeof(action) == "string" then
			onZoneAction(player, action)
		end
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
