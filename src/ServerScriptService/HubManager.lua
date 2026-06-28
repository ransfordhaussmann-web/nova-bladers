local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubManager = {}

local remotesFolder
local zoneTriggers = {}
local playerState = {}

local function getRemotes()
	if remotesFolder then
		return remotesFolder
	end
	local nova = ReplicatedStorage:WaitForChild("NovaBladers")
	remotesFolder = nova:WaitForChild("Remotes")
	return remotesFolder
end

local function getSpawnCFrame()
	return CFrame.new(HubConfig.HUB_ORIGIN + HubConfig.SPAWN_OFFSET)
end

local function getArenaCFrame()
	return CFrame.new(HubConfig.ARENA_ORIGIN + Vector3.new(0, 4, 0))
end

local function getZoneData(zoneId)
	return HubConfig.ZONES[zoneId]
end

local function isInsideZone(position, trigger)
	local relative = trigger.CFrame:PointToObjectSpace(position)
	local half = trigger.Size / 2
	return math.abs(relative.X) <= half.X
		and math.abs(relative.Y) <= half.Y
		and math.abs(relative.Z) <= half.Z
end

function HubManager.getZoneAtPosition(position)
	for zoneId, trigger in zoneTriggers do
		if isInsideZone(position, trigger) then
			return zoneId
		end
	end
	return nil
end

local function ensurePlayerState(player)
	if not playerState[player] then
		playerState[player] = {
			inHub = true,
			selectedZoneId = "Training",
			selectedMode = HubConfig.ZONES.Training.mode,
		}
	end
	return playerState[player]
end

local function buildModeLabel(zoneId, playerCount)
	local zone = getZoneData(zoneId)
	if not zone then
		return "Modus: Training"
	end

	if playerCount < zone.minPlayers then
		return zone.modeLabel .. string.format(" (%d/%d Spieler)", playerCount, zone.minPlayers)
	end
	return zone.modeLabel
end

local function sendLobbyReady(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local state = ensurePlayerState(player)
	local zone = getZoneData(state.selectedZoneId) or HubConfig.ZONES.Training

	getRemotes().LobbyReady:FireClient(player, {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = buildModeLabel(state.selectedZoneId, #Players:GetPlayers()),
		mode = state.selectedMode,
		zoneId = state.selectedZoneId,
		leaderboard = LeaderboardManager.getTop(5),
	})
end

local function sendZoneHighlight(player, zoneId)
	local zone = getZoneData(zoneId)
	if not zone then
		return
	end

	getRemotes().HubZoneHighlight:FireClient(player, {
		zoneId = zoneId,
		modeLabel = buildModeLabel(zoneId, #Players:GetPlayers()),
		mode = zone.mode,
		color = zone.color,
	})
end

function HubManager.setZoneTriggers(triggers)
	zoneTriggers = triggers
end

function HubManager.teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local state = ensurePlayerState(player)
	state.inHub = true
	root.CFrame = getSpawnCFrame()
	sendLobbyReady(player)
	sendZoneHighlight(player, state.selectedZoneId)
end

function HubManager.enterArena(player, zoneId)
	local state = ensurePlayerState(player)
	local resolvedZoneId = zoneId or state.selectedZoneId or "Training"
	local zone = getZoneData(resolvedZoneId) or HubConfig.ZONES.Training

	state.selectedZoneId = resolvedZoneId
	state.selectedMode = zone.mode
	state.inHub = false

	local character = player.Character
	if character then
		local root = character:FindFirstChild("HumanoidRootPart")
		if root then
			root.CFrame = getArenaCFrame()
		end
	end

	return zone.mode
end

function HubManager.returnToHub(player)
	HubManager.teleportToHub(player)
end

function HubManager.getSelectedMode(player)
	local state = ensurePlayerState(player)
	return state.selectedMode
end

function HubManager.isInHub(player)
	local state = ensurePlayerState(player)
	return state.inHub
end

function HubManager.onPlayerAdded(player)
	ensurePlayerState(player)

	player.CharacterAdded:Connect(function()
		task.defer(function()
			local state = ensurePlayerState(player)
			if state.inHub then
				HubManager.teleportToHub(player)
			end
		end)
	end)

	task.defer(function()
		sendLobbyReady(player)
		local state = ensurePlayerState(player)
		sendZoneHighlight(player, state.selectedZoneId)
	end)
end

function HubManager.onPlayerRemoving(player)
	playerState[player] = nil
end

function HubManager.updatePlayerZones()
	for _, player in Players:GetPlayers() do
		local state = ensurePlayerState(player)
		if not state.inHub then
			continue
		end

		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if not root then
			continue
		end

		local zoneId = HubManager.getZoneAtPosition(root.Position) or state.selectedZoneId
		if zoneId ~= state.selectedZoneId then
			local zone = getZoneData(zoneId)
			if zone then
				state.selectedZoneId = zoneId
				state.selectedMode = zone.mode
				sendZoneHighlight(player, zoneId)
				sendLobbyReady(player)
			end
		end
	end
end

function HubManager.bindPrompts(hubModel)
	local zonesFolder = hubModel:FindFirstChild("Zones")
	if not zonesFolder then
		return
	end

	for _, zoneFolder in zonesFolder:GetChildren() do
		local pad = zoneFolder:FindFirstChild("ZonePad")
		local prompt = pad and pad:FindFirstChild("EnterPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				local zoneId = prompt:GetAttribute("ZoneId")
				HubManager.enterArena(player, zoneId)
			end)
		end
	end
end

function HubManager.bindRemotes()
	local remotes = getRemotes()

	remotes.EnterArena.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			HubManager.enterArena(player, zoneId)
		else
			HubManager.enterArena(player)
		end
	end)

	if remotes:FindFirstChild("ReturnToHub") then
		remotes.ReturnToHub.OnServerEvent:Connect(function(player)
			HubManager.returnToHub(player)
		end)
	end
end

function HubManager.refreshLobby(player)
	sendLobbyReady(player)
end

return HubManager
