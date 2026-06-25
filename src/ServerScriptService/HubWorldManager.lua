local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = RemotesSetup.ensure(NovaBladers)

local HubWorldManager = {}
local playerStates = {}

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function getCharacterRoot(player)
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function teleportPlayer(player, cframe)
	local root = getCharacterRoot(player)
	if not root then
		return
	end
	root.CFrame = cframe
end

local function getState(player)
	if not playerStates[player] then
		playerStates[player] = { inHub = true, inArena = false, activeZone = nil }
	end
	return playerStates[player]
end

local function getActiveZone(player)
	local root = getCharacterRoot(player)
	if not root then
		return nil
	end

	local pos = root.Position
	for _, zone in HubConfig.ZONES do
		local flat = Vector3.new(pos.X, zone.position.Y, pos.Z)
		if (flat - zone.position).Magnitude <= zone.radius then
			return zone
		end
	end
	return nil
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local state = getState(player)
	Remotes.LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = PlayerDataManager.getRankPoints(data),
		leaderboard = LeaderboardManager.getTop(5),
		modeLabel = getModeLabel(),
		inHub = state.inHub,
		inArena = state.inArena,
	})
end

local function sendZoneHint(player, zone)
	Remotes.HubZoneHint:FireClient(player, zone and {
		id = zone.id,
		name = zone.name,
		prompt = zone.prompt,
	} or nil)
end

local function enterArena(player)
	local state = getState(player)
	state.inHub = false
	state.inArena = true
	teleportPlayer(player, HubConfig.ARENA_SPAWN)
	sendZoneHint(player, nil)
	sendLobbyReady(player)
end

local function openBeySelect(player)
	Remotes.OpenBeySelect:FireClient(player)
end

local function viewLeaderboard(player)
	local data = PlayerDataManager.get(player)
	Remotes.HubZoneHint:FireClient(player, {
		id = "HallOfFame",
		name = "Ruhmeshalle",
		prompt = "Top Spieler",
		leaderboard = LeaderboardManager.getTop(5),
		wins = data.Wins,
		losses = data.Losses,
		rank = PlayerDataManager.getRankPoints(data),
	})
end

local ZONE_ACTIONS = {
	enterArena = enterArena,
	openBeySelect = openBeySelect,
	viewLeaderboard = viewLeaderboard,
}

function HubWorldManager.returnToHub(player)
	local state = getState(player)
	state.inHub = true
	state.inArena = false
	state.activeZone = nil
	teleportPlayer(player, HubConfig.SPAWN)
	sendZoneHint(player, nil)
	sendLobbyReady(player)
end

function HubWorldManager.init()
	HubWorldBuilder.build()

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)
		local state = getState(player)
		state.inHub = true
		state.inArena = false

		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			if state.inHub and not state.inArena then
				teleportPlayer(player, HubConfig.SPAWN)
			end
			sendLobbyReady(player)
		end)

		if player.Character then
			teleportPlayer(player, HubConfig.SPAWN)
		end
		sendLobbyReady(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerStates[player] = nil
	end)

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		local zone = getActiveZone(player)
		if zone and zone.action ~= "enterArena" then
			return
		end
		if not zone then
			local state = getState(player)
			if not state.inHub then
				return
			end
		end
		enterArena(player)
	end)

	Remotes.HubInteract.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) ~= "string" then
			return
		end

		local zone = HubConfig.ZONES[zoneId]
		if not zone then
			return
		end

		local active = getActiveZone(player)
		if not active or active.id ~= zoneId then
			return
		end

		local action = ZONE_ACTIONS[zone.action]
		if action then
			action(player)
		end
	end)

	RunService.Heartbeat:Connect(function()
		for _, player in Players:GetPlayers() do
			local state = getState(player)
			if state.inHub and not state.inArena then
				local zone = getActiveZone(player)
				if zone and zone.id ~= state.activeZone then
					state.activeZone = zone.id
					sendZoneHint(player, zone)
				elseif not zone and state.activeZone then
					state.activeZone = nil
					sendZoneHint(player, nil)
				end
			end
		end
	end)
end

_G.NovaBladersReturnToHub = function(player)
	HubWorldManager.returnToHub(player)
end

return HubWorldManager
