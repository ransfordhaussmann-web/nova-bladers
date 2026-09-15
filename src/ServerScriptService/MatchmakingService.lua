local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local started = false
local resolveDefaultMode = nil

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			waitingSince = nil,
		}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	if queue then
		for i, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, i)
				break
			end
		end
		if #queue.players == 0 then
			queue.waitingSince = nil
		end
	end

	playerQueue[player] = nil
end

local function getQueueStatus(modeId, queue)
	local mode = MatchModes.get(modeId)
	local count = #queue.players
	local status = "waiting"

	if count >= mode.minPlayers then
		if MatchStateService.isArenaBusy() then
			status = "pending"
		else
			status = "ready"
		end
	end

	local secondsLeft = nil
	if modeId == "ffa" and count >= mode.minPlayers and queue.waitingSince then
		local elapsed = os.clock() - queue.waitingSince
		secondsLeft = math.max(0, math.ceil(MatchmakingConfig.FFA_FILL_TIMEOUT - elapsed))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
	}
end

local function buildPlayerUpdate(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local queue = queues[entry.modeId]
	local status = getQueueStatus(entry.modeId, queue)
	local position = 0
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = status.modeLabel,
		position = position,
		playersInQueue = status.playersInQueue,
		minPlayers = status.minPlayers,
		maxPlayers = status.maxPlayers,
		status = status.status,
		secondsLeft = status.secondsLeft,
	}
end

local function broadcastQueue(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
	end
end

local function broadcastQueueGroup(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, player in queue.players do
		broadcastQueue(player)
	end
end

local function canStartMode(modeId, queue)
	local mode = MatchModes.get(modeId)
	local count = #queue.players
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" and queue.waitingSince then
		return os.clock() - queue.waitingSince >= MatchmakingConfig.FFA_FILL_TIMEOUT
	end
	return modeId ~= "ffa"
end

local function takePlayers(modeId, amount)
	local queue = queues[modeId]
	local taken = {}
	for i = 1, math.min(amount, #queue.players) do
		local player = queue.players[1]
		table.remove(queue.players, 1)
		removeFromQueue(player)
		table.insert(taken, player)
	end
	if #queue.players == 0 then
		queue.waitingSince = nil
	end
	return taken
end

local function startMatch(modeId)
	local queue = queues[modeId]
	local mode = MatchModes.get(modeId)
	if not queue or #queue.players < mode.minPlayers then
		return false
	end
	if MatchStateService.isArenaBusy() then
		broadcastQueueGroup(modeId)
		return false
	end

	local playerCount = math.min(#queue.players, mode.maxPlayers)
	local matchPlayers = takePlayers(modeId, playerCount)
	if #matchPlayers == 0 then
		return false
	end

	MatchStateService.setArenaBusy(true)
	for _, player in matchPlayers do
		HubService.leaveHubForArena(player)
	end
	MatchReady:Fire(matchPlayers)
	return true
end

local function eachModeId(callback)
	for modeId in pairs(MatchModes.all()) do
		callback(modeId)
	end
end

local function tryStartMatches()
	for modeId in pairs(MatchModes.all()) do
		local queue = queues[modeId]
		if queue and canStartMode(modeId, queue) then
			if startMatch(modeId) then
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		modeId = resolveDefaultMode and resolveDefaultMode() or "training"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end
	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			broadcastQueue(player)
			return
		end
		removeFromQueue(player)
	end

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = { modeId = modeId }

	if #queue.players >= mode.minPlayers and not queue.waitingSince then
		queue.waitingSince = os.clock()
	end

	broadcastQueueGroup(modeId)
	tryStartMatches()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueGroup(modeId)
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	tryStartMatches()
	eachModeId(broadcastQueueGroup)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true
	resolveDefaultMode = options and options.resolveDefaultMode

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			tryStartMatches()
			eachModeId(function(modeId)
				local queue = queues[modeId]
				if queue and #queue.players > 0 then
					broadcastQueueGroup(modeId)
				end
			end)
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
