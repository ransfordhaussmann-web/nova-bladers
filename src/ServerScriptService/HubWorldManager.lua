local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}
local hubFolder
local remotes
local playersInArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

local function buildLobbyPayload(player, inHub)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = inHub,
	}
end

local function findArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("ArenaSpawn")
		if spawn then
			return spawn
		end
	end
	return workspace:FindFirstChild("ArenaSpawn")
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.spawnInHub(player)
	playersInArena[player] = nil
	if hubFolder then
		teleportCharacter(player, HubWorldBuilder.getSpawnCFrame(hubFolder))
	end
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

function HubWorldManager.teleportToArena(player)
	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] ArenaSpawn nicht gefunden — Hub bleibt aktiv.")
		return false
	end

	playersInArena[player] = true
	local offset = Vector3.new(0, 3, 0)
	if spawn:IsA("BasePart") then
		teleportCharacter(player, spawn.CFrame + offset)
	elseif spawn:IsA("SpawnLocation") then
		teleportCharacter(player, spawn.CFrame + offset)
	end
	return true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

local function onPromptTriggered(prompt, player)
	local action = prompt:GetAttribute("HubAction")
	if not action or playersInArena[player] then
		return
	end

	if action == "EnterArena" then
		if HubWorldManager.teleportToArena(player) then
			remotes.EnterArena:FireClient(player)
		end
	elseif action == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif action == "ShowHallOfFame" then
		remotes.ShowHallOfFame:FireClient(player, buildLobbyPayload(player, true))
	end
end

local function wireZonePrompts()
	local zones = hubFolder and hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("HubPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			prompt.Triggered:Connect(function(player)
				onPromptTriggered(prompt, player)
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not playersInArena[player] then
				HubWorldManager.spawnInHub(player)
			end
		end)
	end)

	if player.Character then
		task.defer(function()
			HubWorldManager.spawnInHub(player)
		end)
	end
end

local function onPlayerRemoving(player)
	playersInArena[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.getFolder()
	hubFolder = HubWorldBuilder.build()
	wireZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if playersInArena[player] then
			return
		end
		if HubWorldManager.teleportToArena(player) then
			remotes.EnterArena:FireClient(player)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
		remotes.ReturnToHub:FireClient(player)
	end)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
end

return HubWorldManager
