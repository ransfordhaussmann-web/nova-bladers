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
local playerState = {}
local ZONE_CHECK_INTERVAL = 0.25
local zoneCheckAccum = 0

local function getModeLabel()
	local count = #Players:GetPlayers()
	if count <= 1 then
		return "Modus: Training"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", count)
end

local function buildLobbyPayload(player, opts)
	opts = opts or {}
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = opts.inHub == true,
		inArena = opts.inArena == true,
		showLobbyPanel = opts.showLobbyPanel == true,
	}
end

local function sendLobbyReady(player, opts)
	remotes.LobbyReady:FireClient(player, buildLobbyPayload(player, opts))
end

local function getRootPart(player)
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function teleportToHub(player)
	local root = getRootPart(player)
	if root then
		root.CFrame = CFrame.new(HubConfig.SPAWN_POSITION)
	end
end

local function getNearestZone(position)
	local bestZone
	local bestDist = math.huge
	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist <= zone.radius and dist < bestDist then
			bestZone = zone
			bestDist = dist
		end
	end
	return bestZone
end

local function setPlayerState(player, state)
	playerState[player] = state
end

local function getPlayerState(player)
	return playerState[player] or { inHub = true, inArena = false }
end

function HubWorldManager.sendToHub(player, showLobbyPanel)
	setPlayerState(player, { inHub = true, inArena = false })
	teleportToHub(player)
	sendLobbyReady(player, {
		inHub = true,
		showLobbyPanel = showLobbyPanel == true,
	})
end

function HubWorldManager.sendToArena(player)
	setPlayerState(player, { inHub = false, inArena = true })
	sendLobbyReady(player, { inArena = true })
end

local function startArenaForPlayer(player)
	HubWorldManager.sendToArena(player)
end

local function handleZoneAction(player, zone)
	if zone.action == "enter_arena" then
		startArenaForPlayer(player)
	elseif zone.action == "open_bey_select" then
		remotes.OpenBeySelect:FireClient(player)
	elseif zone.action == "show_lobby" then
		sendLobbyReady(player, { inHub = true, showLobbyPanel = true })
	end
end

local function onHubInteract(player)
	local state = getPlayerState(player)
	if not state.inHub or state.inArena then
		return
	end

	local root = getRootPart(player)
	if not root then return end

	local zone = getNearestZone(root.Position)
	if zone then
		handleZoneAction(player, zone)
	end
end

local function updateZoneHints()
	for _, player in Players:GetPlayers() do
		local state = getPlayerState(player)
		if state.inHub and not state.inArena then
			local root = getRootPart(player)
			if root then
				local zone = getNearestZone(root.Position)
				if zone then
					remotes.HubZoneHint:FireClient(player, {
						zoneId = zone.id,
						name = zone.name,
						hint = zone.hint,
						active = true,
					})
				else
					remotes.HubZoneHint:FireClient(player, { active = false })
				end
			end
		end
	end
end

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
	setPlayerState(player, { inHub = true, inArena = false })

	player.CharacterAdded:Connect(function()
		task.defer(function()
			local state = getPlayerState(player)
			if state.inHub and not state.inArena then
				teleportToHub(player)
			end
		end)
	end)

	sendLobbyReady(player, { inHub = true })
end

local function onPlayerRemoving(player)
	PlayerDataManager.save(player)
	playerState[player] = nil
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build(HubConfig)

	remotes.HubInteract.OnServerEvent:Connect(onHubInteract)
	remotes.EnterArena.OnServerEvent:Connect(startArenaForPlayer)

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	for _, player in Players:GetPlayers() do
		onPlayerAdded(player)
	end

	RunService.Heartbeat:Connect(function(dt)
		zoneCheckAccum += dt
		if zoneCheckAccum >= ZONE_CHECK_INTERVAL then
			zoneCheckAccum = 0
			updateZoneHints()
		end
	end)

	_G.NovaBladersReturnToHub = function(player)
		HubWorldManager.sendToHub(player, false)
	end
end

return HubWorldManager
