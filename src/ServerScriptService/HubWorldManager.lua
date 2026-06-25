local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local RemotesSetup = require(NovaBladers.RemotesSetup)

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local HubWorldManager = {}

local remotes
local leaderboardBoard
local playerState = {}
local zoneById = {}

local function resolvePath(path)
	local node = workspace
	for segment in string.gmatch(path, "[^%.]+") do
		node = node:FindFirstChild(segment)
		if not node then return nil end
	end
	return node
end

local function findArenaSpawn()
	for _, path in HubConfig.ARENA_SPAWN_PATHS do
		local spawn = resolvePath(path)
		if spawn and spawn:IsA("BasePart") then
			return spawn
		end
	end
	return nil
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return string.format("Modus: FFA (%d Spieler)", playerCount)
end

local function buildPayload(player, state)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(#Players:GetPlayers()),
		leaderboard = LeaderboardManager.getTop(5),
		inHub = state.inHub,
		inArena = state.inArena,
	}
end

local function sendLobbyReady(player)
	local state = playerState[player]
	if not state then return end
	remotes.LobbyReady:FireClient(player, buildPayload(player, state))
end

local function teleportCharacter(player, cframe)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.returnToHub(player)
	local state = playerState[player]
	if not state then return end

	state.inHub = true
	state.inArena = false
	state.activeZone = nil

	teleportCharacter(player, HubConfig.SPAWN)
	sendLobbyReady(player)
end

local function enterArena(player)
	local state = playerState[player]
	if not state or not state.inHub then return end

	local spawn = findArenaSpawn()
	if not spawn then
		warn("[NovaBladers] Arena-Spawn nicht gefunden — prüfe Workspace.Arena.Spawn")
		return
	end

	state.inHub = false
	state.inArena = true
	state.activeZone = nil

	teleportCharacter(player, spawn.CFrame + Vector3.new(0, 3, 0))
	sendLobbyReady(player)
end

local function openBeySelect(player)
	if not playerState[player] or not playerState[player].inHub then return end
	remotes.OpenBeySelect:FireClient(player)
end

local ZONE_ACTIONS = {
	enterArena = enterArena,
	openBeySelect = openBeySelect,
	hallOfFame = function() end,
}

local function getNearestZone(rootPart)
	local nearest
	local nearestDist = HubConfig.ZONE_ACTIVATE_DISTANCE

	for zoneId, zone in zoneById do
		local dist = (rootPart.Position - zone.position).Magnitude
		if dist <= nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end

	return nearest
end

local function onZoneHint(player, zone)
	if not zone then
		remotes.HubZoneHint:FireClient(player, { visible = false })
		return
	end

	remotes.HubZoneHint:FireClient(player, {
		visible = true,
		label = zone.label,
		hint = zone.hint,
		action = zone.action,
		canInteract = zone.action ~= "hallOfFame",
	})
end

local function handleInteract(player)
	local state = playerState[player]
	if not state or not state.inHub or not state.activeZone then return end

	local zone = zoneById[state.activeZone]
	if not zone then return end

	local action = ZONE_ACTIONS[zone.action]
	if action then
		action(player)
	end
end

function HubWorldManager.init()
	remotes = RemotesSetup.ensure()

	local _, board = HubWorldBuilder.build()
	leaderboardBoard = board

	for _, zone in HubConfig.ZONES do
		zoneById[zone.id] = zone
	end

	Players.PlayerAdded:Connect(function(player)
		playerState[player] = { inHub = true, inArena = false, activeZone = nil }

		player.CharacterAdded:Connect(function()
			task.wait(0.1)
			if playerState[player] and playerState[player].inHub then
				teleportCharacter(player, HubConfig.SPAWN)
			end
		end)

		local data = PlayerDataManager.load(player)
		local rankPoints = PlayerDataManager.getRankPoints(data)
		LeaderboardManager.submit(player, rankPoints)

		task.defer(function()
			sendLobbyReady(player)
			if leaderboardBoard then
				HubWorldBuilder.updateLeaderboardBoard(
					leaderboardBoard,
					LeaderboardManager.getTop(5)
				)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		PlayerDataManager.save(player)
		playerState[player] = nil
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		enterArena(player)
	end)

	game:GetService("RunService").Heartbeat:Connect(function()
		for player, state in pairs(playerState) do
			if not state.inHub then
				continue
			end

			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			if not root then
				continue
			end

			local zone = getNearestZone(root)
			local zoneId = zone and zone.id or nil

			if zoneId ~= state.activeZone then
				state.activeZone = zoneId
				onZoneHint(player, zone)
			end
		end
	end)

	_G.NovaBladersReturnToHub = HubWorldManager.returnToHub
end

function HubWorldManager.onInteract(player)
	handleInteract(player)
end

return HubWorldManager
