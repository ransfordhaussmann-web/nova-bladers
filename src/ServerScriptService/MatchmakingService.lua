--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReadyBindable
local onPlayerEnterArena

local queues = {}
local playerQueue = {}
local fillTokens = {}

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {}, fillStartedAt = nil }
	end
	return queues[modeId]
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players
	local pending = MatchStateService.isBusy()
	local fillRemaining = nil

	if queue.fillStartedAt and mode.fillTimeout > 0 then
		local elapsed = os.clock() - queue.fillStartedAt
		fillRemaining = math.max(0, math.ceil(mode.fillTimeout - elapsed))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		fillRemaining = fillRemaining,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	if not remotes or not remotes.QueueUpdate then
		return
	end

	local queue = ensureQueue(modeId)
	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function removeFromQueue(player, modeId)
	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	if #queue.players < getMode(modeId).minPlayers then
		queue.fillStartedAt = nil
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	end
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	removeFromQueue(player, modeId)
	broadcastQueueUpdate(modeId)

	if remotes and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, {
			modeId = nil,
			inQueue = false,
			queued = 0,
			pending = false,
		})
	end
end

local function shouldStart(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout <= 0 then
		return count >= mode.minPlayers
	end

	if queue.fillStartedAt then
		local elapsed = os.clock() - queue.fillStartedAt
		return elapsed >= mode.fillTimeout
	end

	return false
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)

	if mode.fillTimeout <= 0 or #queue.players < mode.minPlayers then
		return
	end

	if queue.fillStartedAt then
		return
	end

	queue.fillStartedAt = os.clock()
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if MatchStateService.isBusy() then
			return
		end
		if shouldStart(modeId) then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)

	broadcastQueueUpdate(modeId)
end

local function takePlayersForMatch(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local matchPlayers = {}

	for i = 1, math.min(#queue.players, mode.maxPlayers) do
		local queuedPlayer = queue.players[i]
		table.insert(matchPlayers, queuedPlayer)
		playerQueue[queuedPlayer] = nil
	end

	queue.players = {}
	queue.fillStartedAt = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1

	return matchPlayers
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	if not shouldStart(modeId) then
		return false
	end

	local mode = getMode(modeId)
	if not mode then
		return false
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers < mode.minPlayers then
		return false
	end

	MatchStateService.setBusy(true)

	for _, queuedPlayer in matchPlayers do
		if onPlayerEnterArena then
			onPlayerEnterArena(queuedPlayer)
		end
		if remotes and remotes.QueueUpdate then
			remotes.QueueUpdate:FireClient(queuedPlayer, {
				modeId = modeId,
				inQueue = false,
				matchStarting = true,
				modeLabel = mode.label,
			})
		end
	end

	if matchReadyBindable then
		matchReadyBindable:Fire({
			players = matchPlayers,
			mode = modeId,
		})
	end

	return true
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	if #queue.players >= mode.maxPlayers then
		return false
	end

	for _, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return true
		end
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId

	if #queue.players >= mode.minPlayers then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)

	if not MatchStateService.isBusy() and shouldStart(modeId) then
		MatchmakingService.tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)

	local startOrder = { "training", "pvp", "ffa" }
	for _, modeId in startOrder do
		local mode = getMode(modeId)
		local queue = ensureQueue(modeId)
		if #queue.players >= mode.minPlayers then
			if mode.fillTimeout > 0 and not queue.fillStartedAt then
				startFillTimer(modeId)
			end
			if MatchmakingService.tryStartMatch(modeId) then
				return
			end
		end
	end

	for modeId in pairs(queues) do
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyBindable = options.matchReadyBindable
	onPlayerEnterArena = options.onPlayerEnterArena

	for _, mode in MatchModes.all() do
		ensureQueue(mode.id)
	end

	if remotes.QueueJoin then
		remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
			if typeof(modeId) ~= "string" then
				return
			end
			MatchmakingService.joinQueue(player, modeId)
		end)
	end

	if remotes.QueueLeave then
		remotes.QueueLeave.OnServerEvent:Connect(function(player)
			MatchmakingService.leaveQueue(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
