local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local ffaFillToken = {}
local ffaFillActive = {}
local remotes = nil
local MatchReady = nil
local onMatchStart = nil

local MODE_IDS = { "training", "pvp", "ffa" }

local function initQueues()
	for _, modeId in MODE_IDS do
		queues[modeId] = {}
	end
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function queueIndex(queue, player)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	local index = queueIndex(queue, player)
	if index then
		table.remove(queue, index)
	end
	playerQueue[player] = nil

	if modeId == "ffa" then
		ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
		ffaFillActive[modeId] = false
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local position = queueIndex(queue, player) or #queue

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		playersInQueue = #queue,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
	}
end

local function broadcastQueue(player, payload)
	if remotes and remotes.QueueUpdate and player.Parent then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastAllInMode(modeId, status)
	local queue = getQueue(modeId)
	for _, player in queue do
		broadcastQueue(player, buildQueuePayload(player, modeId, status))
	end
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	local amount = math.min(count, #queue)

	for _ = 1, amount do
		local player = table.remove(queue, 1)
		if player then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	return taken
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end
	return #getQueue(modeId) >= mode.minPlayers
end

local function startMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not canStartMatch(modeId) then
		return false
	end

	if GameMatchState.isArenaBusy() then
		broadcastAllInMode(modeId, "pending")
		return false
	end

	local count = math.min(#getQueue(modeId), mode.maxPlayers)
	local players = takePlayers(modeId, count)

	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(getQueue(modeId), player)
			playerQueue[player] = modeId
		end
		return false
	end

	GameMatchState.setArenaBusy(true)
	ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
	ffaFillActive[modeId] = false

	for _, player in players do
		broadcastQueue(player, { inQueue = false, status = "starting" })
	end

	if onMatchStart then
		onMatchStart(players, modeId)
	end
	if MatchReady then
		MatchReady:Fire(players, modeId)
	end

	return true
end

local function scheduleFfaFill(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or ffaFillActive[modeId] then
		return
	end

	ffaFillActive[modeId] = true
	ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
	local token = ffaFillToken[modeId]

	task.delay(mode.fillTimeout, function()
		ffaFillActive[modeId] = false
		if ffaFillToken[modeId] ~= token then
			return
		end
		if canStartMatch(modeId) then
			startMatch(modeId)
		end
	end)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if modeId == "ffa" then
		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers and not ffaFillActive[modeId] then
			scheduleFfaFill(modeId)
		end
		if #queue >= mode.maxPlayers then
			startMatch(modeId)
		end
		return
	end

	if canStartMatch(modeId) then
		startMatch(modeId)
	end
end

local function processAllQueues()
	for modeId in pairs(queues) do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end

	MatchmakingService.leaveQueue(player)

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	local status = GameMatchState.isArenaBusy() and "pending" or "waiting"
	broadcastQueue(player, buildQueuePayload(player, modeId, status))
	broadcastAllInMode(modeId, status)

	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		broadcastQueue(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	broadcastQueue(player, { inQueue = false })
	broadcastAllInMode(modeId, GameMatchState.isArenaBusy() and "pending" or "waiting")
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)
	processAllQueues()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start(options)
	remotes = options.remotes
	MatchReady = options.matchReady
	onMatchStart = options.onMatchStart

	initQueues()

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if options.arenaFree then
		options.arenaFree.Event:Connect(function()
			MatchmakingService.onArenaFree()
		end)
	end

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
