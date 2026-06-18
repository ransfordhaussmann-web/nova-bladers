local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = {}

local remotes
local hubFolder
local playerDataManager
local leaderboardManager
local playersInHub = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
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

local function getHubSpawnCFrame()
	if hubFolder then
		local spawn = hubFolder:FindFirstChild("HubSpawn")
		if spawn then
			return spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
	return CFrame.new(HubConfig.SPAWN_POSITION)
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		character:PivotTo(targetCFrame)
	end
end

local function buildLobbyPayload(player, inHub)
	local data = playerDataManager.get(player)
	local rankPoints = playerDataManager.getRankPoints(data)
	local leaderboard = leaderboardManager.getTop(5)

	local rank = 0
	for _, entry in leaderboard do
		if entry.name == player.Name then
			rank = entry.rank
			break
		end
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rank,
		rankPoints = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = inHub,
	}
end

function HubWorldManager.sendLobbyReady(player, inHub)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, inHub))
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	teleportCharacter(player, getHubSpawnCFrame())
	remotes.ReturnToHub:FireClient(player)
	HubWorldManager.sendLobbyReady(player, true)
end

local function enterArena(player)
	playersInHub[player] = nil
	local arenaSpawn = findArenaSpawn()
	if arenaSpawn then
		teleportCharacter(player, arenaSpawn.CFrame + Vector3.new(0, 3, 0))
	else
		warn("[HubWorldManager] Kein ArenaSpawn gefunden — Spieler bleibt im Hub")
		playersInHub[player] = true
		return
	end
	-- Lobby-Panel ausblenden (z. B. nach Ruhmeshalle-Besuch)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, true))
end

local function onZonePromptTriggered(player, action)
	if action == "EnterArena" then
		enterArena(player)
	elseif action == "OpenBeySelect" then
		remotes.BeySelectOpen:FireClient(player)
	elseif action == "ShowStats" then
		HubWorldManager.sendLobbyReady(player, false)
	end
end

local function bindZonePrompts()
	if not hubFolder then
		return
	end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, marker in zones:GetChildren() do
		local prompt = marker:FindFirstChild("ZonePrompt")
		if prompt and not prompt:GetAttribute("Bound") then
			prompt:SetAttribute("Bound", true)
			prompt.Triggered:Connect(function(player)
				local action = prompt:GetAttribute("HubAction")
				if action then
					onZonePromptTriggered(player, action)
				end
			end)
		end
	end
end

function HubWorldManager.init(deps)
	playerDataManager = deps.playerDataManager
	leaderboardManager = deps.leaderboardManager

	remotes = RemotesSetup.ensure()
	hubFolder = HubWorldBuilder.build()
	bindZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		playersInHub[player] = true
		player.CharacterAdded:Connect(function()
			task.defer(function()
				if playersInHub[player] then
					teleportCharacter(player, getHubSpawnCFrame())
					HubWorldManager.sendLobbyReady(player, true)
				end
			end)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		playersInHub[player] = true
		HubWorldManager.sendLobbyReady(player, true)
	end
end

return HubWorldManager
