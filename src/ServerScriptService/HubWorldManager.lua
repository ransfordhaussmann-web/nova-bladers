local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local inArena = {}

local function resolveArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local current = game
		for segment in string.gmatch(path, "[^%.]+") do
			if segment == "Workspace" then
				current = workspace
			else
				current = current and current:FindFirstChild(segment)
			end
		end
		if current and current:IsA("BasePart") then
			return current
		end
	end
	return nil
end

local function getHubSpawn()
	if not hubModel then return nil end
	return hubModel:FindFirstChild("HubSpawn")
end

local function teleportToPart(player, part)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not part then return end
	root.CFrame = part.CFrame + Vector3.new(0, 3, 0)
end

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		inHub = not inArena[player],
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = nil
	local spawn = getHubSpawn()
	if spawn then
		player.RespawnLocation = spawn
	end
	if player.Character then
		teleportToPart(player, spawn)
	end
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	local arenaSpawn = resolveArenaSpawn()
	if not arenaSpawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — Arena.ArenaSpawn in Workspace anlegen.")
		return false
	end

	inArena[player] = true
	player.RespawnLocation = nil
	teleportToPart(player, arenaSpawn)
	remotes.LobbyReady:FireClient(player, HubWorldManager.buildLobbyPayload(player))
	return true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if inArena[player] then return end
			HubWorldManager.spawnInHub(player)
		end)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

local function onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	remotes.OpenBeySelect.OnServerEvent:Connect(function(player)
		if inArena[player] then return end
		remotes.OpenBeySelect:FireClient(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		task.spawn(onPlayerAdded, player)
	end
end

return HubWorldManager
