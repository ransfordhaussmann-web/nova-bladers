--[[
	MatchmakingService — per-mode queues with fill timeout and arena-pending state.
]]

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
local fillTokens = {}
local started = false

local handlers = {
	leaveHubForArena = nil,
	getPhase = nil,
}

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	local pending = not MatchStateService.isIdle()

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = size,
		neededPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		status = pending
			and "Arena belegt — Warteschlange aktiv"
			or string.format("Warteschlange: %d/%d", size, mode.minPlayers),
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate()
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(taken, nextPlayer)
			playerQueue[nextPlayer] = nil
		end
	end
	return taken
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setBusy()
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1

	for _, player in playerList do
		if handlers.leaveHubForArena then
			handlers.leaveHubForArena(player)
		end
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, starting = true })
	end

	broadcastQueueUpdate()
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	return size >= mode.minPlayers and size <= mode.maxPlayers
end

local function tryStartMode(modeId)
	if not MatchStateService.isIdle() then
		broadcastQueueUpdate()
		return
	end

	local mode = MatchModes.get(modeId)
	if not canStartMode(modeId) then
		return
	end

	if mode.fillTimeout > 0 and getQueueSize(modeId) < mode.maxPlayers then
		return
	end

	local players = takePlayersFromQueue(modeId, mode.maxPlayers)
	if #players >= mode.minPlayers then
		startMatch(modeId, players)
	end
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 or getQueueSize(modeId) < mode.minPlayers then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if not MatchStateService.isIdle() then
			return
		end
		if not canStartMode(modeId) then
			return
		end

		local players = takePlayersFromQueue(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			startMatch(modeId, players)
		end
	end)
end

local function tryAllQueues()
	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
	end
end

function MatchmakingService.register(newHandlers)
	handlers = newHandlers
end

function MatchmakingService.getQuickMatchModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.QUICK_MATCH_FFA_THRESHOLD then
		return "ffa"
	elseif count >= 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if handlers.getPhase and handlers.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	broadcastQueueUpdate()

	if mode.fillTimeout > 0 and getQueueSize(modeId) >= mode.minPlayers then
		scheduleFillTimeout(modeId)
	end

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setIdle()
	task.defer(tryAllQueues)
end

function MatchmakingService.start(remotes, bindables)
	if started then
		return
	end
	started = true

	Remotes = remotes
	Bindables = bindables
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getQuickMatchModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		task.delay(MatchmakingConfig.PENDING_RETRY_INTERVAL, tryAllQueues)
	end)
end

return MatchmakingService
