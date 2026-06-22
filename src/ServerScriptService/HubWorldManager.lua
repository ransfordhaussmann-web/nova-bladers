local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hub
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
	for _, pathName in HubConfig.ARENA_PATHS do
		local arena = Workspace:FindFirstChild(pathName)
		if arena then
			for _, spawnName in HubConfig.ARENA_SPAWN_NAMES do
				local spawn = arena:FindFirstChild(spawnName, true)
				if spawn and spawn:IsA("BasePart") then
					return spawn.CFrame + Vector3.new(0, 3, 0)
				end
			end
			if arena:IsA("BasePart") then
				return arena.CFrame + Vector3.new(0, 5, 0)
			end
		end
	end
	return CFrame.new(0, 10, 0)
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local leaderboard = LeaderboardManager.getTop(5)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = leaderboard,
		inHub = true,
	}
end

function HubWorldManager.refreshLeaderboard()
	if not hub then return end
	HubWorldBuilder.buildLeaderboardBoard(hub, LeaderboardManager.getTop(5))
end

function HubWorldManager.sendLobbyReady(player)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubWorldManager.spawnInHub(player)
	playersInHub[player] = true
	teleportCharacter(player, CFrame.new(HubConfig.SPAWN))
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.returnToHub(player)
	playersInHub[player] = true
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.enterArena(player)
	playersInHub[player] = nil
	teleportCharacter(player, findArenaSpawn())
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.getZoneAtPosition(position)
	for _, zone in HubConfig.ZONES do
		local half = zone.size / 2
		local min = zone.position - half
		local max = zone.position + half
		if position.X >= min.X and position.X <= max.X
			and position.Y >= min.Y and position.Y <= max.Y
			and position.Z >= min.Z and position.Z <= max.Z then
			return zone
		end
	end
	return nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build()
	HubWorldManager.refreshLeaderboard()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not playersInHub[player] then return end
		HubWorldManager.enterArena(player)
	end)

	remotes.HubZoneAction.OnServerEvent:Connect(function(player, action)
		if not playersInHub[player] then return end
		if action == "enter_arena" then
			HubWorldManager.enterArena(player)
		elseif action == "open_bey_select" then
			remotes.OpenBeySelect:FireClient(player)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

		player.CharacterAdded:Connect(function()
			task.wait(0.2)
			if playersInHub[player] ~= false then
				HubWorldManager.spawnInHub(player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		playersInHub[player] = nil
		PlayerDataManager.save(player)
	end)

	for _, player in Players:GetPlayers() do
		PlayerDataManager.load(player)
		local data = PlayerDataManager.get(player)
		LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
		if player.Character then
			HubWorldManager.spawnInHub(player)
		end
	end
end

return HubWorldManager
