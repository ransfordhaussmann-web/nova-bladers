local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local HubCallbacks = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaFree = true
local ffaFillToken = 0
local started = false

local function getQueueSize(modeId)
	local count = 0
	for _ in queues[modeId] do
		count += 1
	end
	return count
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end
	queues[entry.modeId][player] = nil
	playerQueue[player] = nil
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return nil
	end

	local mode = MatchModes.get(entry.modeId)
	local waiting = getQueueSize(entry.modeId)
	local status = entry.status
	if not arenaFree and status == GameMatchState.QueueWaiting then
		status = GameMatchState.QueuePending
	end

	return {
		modeId = entry.modeId,
		modeLabel = mode.label,
		waiting = waiting,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaFree = arenaFree,
	}
end

local function broadcastQueueUpdate()
	for player in playerQueue do
		if player.Parent then
			local payload = buildQueuePayload(player)
			if payload then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function popPlayers(modeId, count)
	local mode = MatchModes.get(modeId)
	local picked = {}
	local limit = math.min(count, mode.maxPlayers)

	for player in queues[modeId] do
		if player.Parent and #picked < limit then
			table.insert(picked, player)
		end
	end

	for _, player in picked do
		removeFromQueue(player)
	end

	return picked
end

local function markPlayersArena(players)
	for _, player in players do
		if HubCallbacks.leaveHubForArena then
			HubCallbacks.leaveHubForArena(player)
		end
	end
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	arenaFree = false
	ffaFillToken += 1
	markPlayersArena(players)
	broadcastQueueUpdate()
	Bindables.MatchReady:Fire(modeId, players)
end

local function tryStartTraining()
	if not arenaFree then
		return
	end
	if getQueueSize("training") < MatchmakingConfig.TRAINING_PLAYERS then
		return
	end
	local players = popPlayers("training", MatchmakingConfig.TRAINING_PLAYERS)
	launchMatch("training", players)
end

local function tryStartPvp()
	if not arenaFree then
		return
	end
	if getQueueSize("pvp") < MatchmakingConfig.PVP_PLAYERS then
		return
	end
	local players = popPlayers("pvp", MatchmakingConfig.PVP_PLAYERS)
	launchMatch("pvp", players)
end

local function tryStartFfa()
	if not arenaFree then
		return
	end

	local size = getQueueSize("ffa")
	if size < MatchmakingConfig.FFA_MIN_PLAYERS then
		ffaFillToken += 1
		return
	end

	if size >= MatchmakingConfig.FFA_MAX_PLAYERS then
		local players = popPlayers("ffa", MatchmakingConfig.FFA_MAX_PLAYERS)
		launchMatch("ffa", players)
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken or not arenaFree then
			return
		end
		local currentSize = getQueueSize("ffa")
		if currentSize < MatchmakingConfig.FFA_MIN_PLAYERS then
			return
		end
		local players = popPlayers("ffa", MatchmakingConfig.FFA_MAX_PLAYERS)
		launchMatch("ffa", players)
	end)
end

local function tryStartMatch(modeId)
	if modeId == "training" then
		tryStartTraining()
	elseif modeId == "pvp" then
		tryStartPvp()
	elseif modeId == "ffa" then
		tryStartFfa()
	end
end

local function tryStartAllQueues()
	for _, mode in MatchModes.getAll() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.registerHubCallbacks(callbacks)
	HubCallbacks = callbacks
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if playerQueue[player] then
		removeFromQueue(player)
	end

	queues[modeId][player] = true
	playerQueue[player] = {
		modeId = modeId,
		status = GameMatchState.QueueWaiting,
	}

	broadcastQueueUpdate()
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	if modeId == "ffa" and getQueueSize("ffa") < MatchmakingConfig.FFA_MIN_PLAYERS then
		ffaFillToken += 1
	end

	if HubCallbacks.returnToHub then
		HubCallbacks.returnToHub(player)
	end

	broadcastQueueUpdate()
end

function MatchmakingService.onArenaFree()
	arenaFree = true
	broadcastQueueUpdate()
	tryStartAllQueues()
end

function MatchmakingService.isArenaFree()
	return arenaFree
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			local modeId = playerQueue[player].modeId
			removeFromQueue(player)
			if modeId == "ffa" and getQueueSize("ffa") < MatchmakingConfig.FFA_MIN_PLAYERS then
				ffaFillToken += 1
			end
			broadcastQueueUpdate()
		end
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
