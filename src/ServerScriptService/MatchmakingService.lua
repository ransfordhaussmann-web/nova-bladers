local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local hubCallbacks = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillToken = 0,
			pending = false,
		}
	end
	return queues[modeId]
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if not queue then
		playerQueue[player] = nil
		return
	end

	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil
	queue.fillToken += 1
	queue.pending = false
	MatchmakingService.broadcastQueueUpdate(modeId)
end

local function buildQueuePayload(modeId, queue)
	local mode = MatchModes.get(modeId)
	local status = "waiting"
	if queue.pending then
		status = "pending"
	elseif #queue.players >= mode.maxPlayers then
		status = "full"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

function MatchmakingService.broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	local payload = buildQueuePayload(modeId, queue)
	for _, player in queue.players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function pullPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = math.min(#queue.players, mode.maxPlayers)

	local matchPlayers = {}
	for i = 1, count do
		table.insert(matchPlayers, queue.players[i])
	end

	for i = 1, count do
		table.remove(queue.players, 1)
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	queue.fillToken += 1
	queue.pending = false
	return matchPlayers
end

local function launchMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)

	if #queue.players < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		queue.pending = true
		MatchmakingService.broadcastQueueUpdate(modeId)
		return
	end

	local matchPlayers = pullPlayersForMatch(modeId)
	if #matchPlayers < mode.minPlayers then
		return
	end

	if hubCallbacks.onMatchStart then
		hubCallbacks.onMatchStart(matchPlayers, modeId)
	end

	MatchStateService.setBusy(true)
	Bindables.MatchReady:Fire(modeId, matchPlayers)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = ensureQueue(modeId)
	queue.fillToken += 1
	local token = queue.fillToken

	task.delay(mode.fillTimeout, function()
		if token ~= queue.fillToken then
			return
		end
		local current = ensureQueue(modeId)
		if #current.players >= mode.minPlayers then
			launchMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)

	if #queue.players >= mode.maxPlayers then
		launchMatch(modeId)
		return
	end

	if #queue.players >= mode.minPlayers and not mode.fillTimeout then
		launchMatch(modeId)
		return
	end

	if mode.fillTimeout and #queue.players >= mode.minPlayers and queue.fillToken == 0 then
		scheduleFillTimeout(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	if playerQueue[player] == modeId then
		MatchmakingService.broadcastQueueUpdate(modeId)
		return
	end

	removePlayerFromQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if hubCallbacks.onQueueJoin then
		hubCallbacks.onQueueJoin(player, modeId)
	end

	MatchmakingService.broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removePlayerFromQueue(player)

	if hubCallbacks.onQueueLeave then
		hubCallbacks.onQueueLeave(player)
	end
end

function MatchmakingService.joinRecommendedQueue(player)
	local modeId = MatchModes.getRecommended(#Players:GetPlayers())
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.onArenaFree()
	for _, modeId in MatchModes.ORDER do
		local mode = MatchModes.get(modeId)
		local queue = queues[modeId]
		if queue and (queue.pending or #queue.players >= mode.minPlayers) then
			launchMatch(modeId)
		end
	end
end

function MatchmakingService.init(callbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	hubCallbacks = callbacks or {}

	for _, modeId in MatchModes.ORDER do
		ensureQueue(modeId)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
