local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local hubModel
local playersInHub = {}
local playerZones = {}
local zoneTimers = {}

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildLobbyPayload(player, showPanel)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		showPanel = showPanel,
	}
end

local function teleportToHub(player)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = CFrame.new(HubConfig.SPAWN + Vector3.new(math.random(-3, 3), 0, math.random(-3, 3)))
end

local function setHubState(player, inHub)
	playersInHub[player] = inHub or nil
	if inHub then
		playerZones[player] = nil
	end
end

function HubWorldManager.isInHub(player)
	return playersInHub[player] == true
end

function HubWorldManager.sendLobbyReady(player, showPanel)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, showPanel))
end

function HubWorldManager.returnToHub(player)
	setHubState(player, true)
	teleportToHub(player)
	HubWorldManager.sendLobbyReady(player, false)
end

local function startArena(player)
	if not playersInHub[player] then
		return
	end
	setHubState(player, false)
	remotes.LeaveHubPanel:FireClient(player)

	if typeof(_G.NovaBladersStartArena) == "function" then
		_G.NovaBladersStartArena(player)
	else
		warn("[NovaBladers] GameManager fehlt — _G.NovaBladersStartArena nicht gesetzt")
	end
end

local function handleZoneAction(player, zoneId)
	local zone = HubConfig.ZONES[zoneId]
	if not zone or not playersInHub[player] then
		return
	end

	if zone.action == "enterArena" then
		startArena(player)
	elseif zone.action == "openBeySelect" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "showStats" then
		HubWorldManager.sendLobbyReady(player, true)
	end
end

local function onZoneEntered(player, zoneId)
	local previous = playerZones[player]
	if previous == zoneId then
		return
	end
	playerZones[player] = zoneId

	local zone = HubConfig.ZONES[zoneId]
	if not zone then
		return
	end

	remotes.HubZonePrompt:FireClient(player, {
		zoneId = zoneId,
		label = zone.label,
		hint = zone.hint,
	})

	if zone.action == "showStats" then
		HubWorldManager.sendLobbyReady(player, true)
	end
end

local function onZoneLeft(player, zoneId)
	if playerZones[player] ~= zoneId then
		return
	end
	playerZones[player] = nil
	remotes.HubZonePrompt:FireClient(player, { zoneId = zoneId, clear = true })

	local zone = HubConfig.ZONES[zoneId]
	if zone and zone.action == "showStats" then
		remotes.LeaveHubPanel:FireClient(player)
	end
end

local function trackPlayerZone(player)
	if not playersInHub[player] then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local position = root.Position
	local activeZone

	for zoneId, zone in HubConfig.ZONES do
		if HubConfig.isInsideZone(zone, position) then
			activeZone = zoneId
			break
		end
	end

	if activeZone then
		onZoneEntered(player, activeZone)
	else
		for zoneId in HubConfig.ZONES do
			if playerZones[player] == zoneId then
				onZoneLeft(player, zoneId)
			end
		end
	end
end

local function hookZonePrompts()
	local zonesFolder = hubModel:WaitForChild("Zones")
	for zoneId, zone in HubConfig.ZONES do
		local zoneFolder = zonesFolder:FindFirstChild(zoneId)
		local pad = zoneFolder and zoneFolder:FindFirstChild("Pad")
		local prompt = pad and pad:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				handleZoneAction(player, zoneId)
			end)
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	setHubState(player, true)

	player.CharacterAdded:Connect(function()
		task.wait(0.1)
		if playersInHub[player] then
			teleportToHub(player)
		end
	end)

	if player.Character then
		teleportToHub(player)
	end

	HubWorldManager.sendLobbyReady(player, false)
end

local function onPlayerRemoving(player)
	playersInHub[player] = nil
	playerZones[player] = nil
	zoneTimers[player] = nil
	PlayerDataManager.save(player)
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	hubModel = HubWorldBuilder.build()
	hookZonePrompts()

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		handleZoneAction(player, "ArenaGate")
	end)

	remotes.HubAction.OnServerEvent:Connect(function(player, zoneId)
		if typeof(zoneId) == "string" then
			handleZoneAction(player, zoneId)
		end
	end)

	remotes.ReturnToHub.OnServerEvent:Connect(function(player)
		HubWorldManager.returnToHub(player)
	end)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end
	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for _, player in Players:GetPlayers() do
			local last = zoneTimers[player] or 0
			if now - last >= HubConfig.ZONE_CHECK_INTERVAL then
				zoneTimers[player] = now
				trackPlayerZone(player)
			end
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.returnToHub(player)
	end
end

return HubWorldManager
