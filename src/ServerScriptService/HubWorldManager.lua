local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local hub = nil
local remotes = nil
local playersInArena = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count >= 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

function HubWorldManager.getArenaSpawn()
	local arena = workspace:FindFirstChild("Arena")
	if arena then
		local spawn = arena:FindFirstChild("ArenaSpawn")
		if spawn then
			return spawn
		end
	end
	return workspace:FindFirstChild("ArenaSpawn")
end

function HubWorldManager.getLobbyPayload(player, options)
	options = options or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = options.inHub ~= false,
		showHallOfFame = options.showHallOfFame == true,
		inArena = options.inArena == true,
	}
end

function HubWorldManager.sendHubState(player, options)
	remotes.LobbyReady:FireClient(player, HubWorldManager.getLobbyPayload(player, options))
end

function HubWorldManager.spawnInHub(player)
	if not hub then
		return
	end

	local spawn = hub:FindFirstChild("HubSpawn")
	local character = player.Character
	if character and spawn then
		character:PivotTo(spawn.CFrame + Vector3.new(0, 3, 0))
	end

	playersInArena[player] = nil
	HubWorldManager.sendHubState(player, { inHub = true })
end

function HubWorldManager.enterArena(player)
	local arenaSpawn = HubWorldManager.getArenaSpawn()
	local character = player.Character
	if character and arenaSpawn then
		local target = arenaSpawn:IsA("BasePart") and arenaSpawn.CFrame or arenaSpawn.CFrame
		character:PivotTo(target + Vector3.new(0, 3, 0))
	end

	playersInArena[player] = true
	remotes.LobbyReady:FireClient(player, HubWorldManager.getLobbyPayload(player, {
		inHub = false,
		inArena = true,
	}))
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

local function onZoneTriggered(player, remoteName)
	if remoteName == "EnterArena" then
		HubWorldManager.enterArena(player)
	elseif remoteName == "OpenBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif remoteName == "HallOfFame" then
		HubWorldManager.sendHubState(player, {
			inHub = true,
			showHallOfFame = true,
		})
	end
end

function HubWorldManager.setupZonePrompts()
	local zones = hub:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zoneFolder in zones:GetChildren() do
		local pad = zoneFolder:FindFirstChild("Pad")
		if not pad then
			continue
		end

		local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
		if not prompt then
			continue
		end

		prompt.Triggered:Connect(function(player)
			onZoneTriggered(player, prompt:GetAttribute("RemoteName"))
		end)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hub = HubWorldBuilder.build(HubConfig)
	HubWorldManager.setupZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager.enterArena(player)
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	local function onPlayerAdded(player)
		PlayerDataManager.load(player)
		player.CharacterAdded:Connect(function()
			if not HubWorldManager.isInArena(player) then
				task.defer(function()
					HubWorldManager.spawnInHub(player)
				end)
			end
		end)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
		if player.Character and not HubWorldManager.isInArena(player) then
			HubWorldManager.spawnInHub(player)
		end
	end
end

return HubWorldManager
