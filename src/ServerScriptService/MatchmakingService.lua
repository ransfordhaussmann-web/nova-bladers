local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local remotes
local bindables
local initialized = false

local function ensureInit()
	if initialized then
		return
	end
	local remoteFolder, bindableFolder = RemotesSetup.ensure()
	MatchmakingService.init(remoteFolder, bindableFolder)
end
local queues = {}
local playerQueue = {}
local ffaFillDeadline = nil
local heartbeatTask = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueueList(modeId, player)
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function getQueueStatus(modeId)
	local config = getModeConfig(modeId)
	local count = #queues[modeId]
	local status = "waiting"

	if MatchStateService.isArenaBusy() and count >= config.minPlayers then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = count,
		playersNeeded = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		pendingReason = status == "pending" and "Arena belegt — Warte auf freies Match" or nil,
	}
end

local function sendQueueUpdate(player)
	local entry = playerQueue[player]
	if not entry then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	remotes.QueueUpdate:FireClient(player, getQueueStatus(entry.modeId))
end

local function broadcastQueueUpdates(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function clearFfaDeadlineIfEmpty()
	if #queues.ffa == 0 then
		ffaFillDeadline = nil
	end
end

local function updateFfaDeadline()
	if #queues.ffa >= MatchmakingConfig.MODES.ffa.minPlayers and not ffaFillDeadline then
		ffaFillDeadline = os.clock() + MatchmakingConfig.MODES.ffa.fillTimeout
	end
	clearFfaDeadlineIfEmpty()
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #queue

	if count < config.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if count >= config.maxPlayers then
			return true
		end
		if ffaFillDeadline and os.clock() >= ffaFillDeadline then
			return true
		end
		return false
	end

	return true
end

local function popPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local take = math.min(#queue, config.maxPlayers)
	local matched = {}

	for _ = 1, take do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matched, player)
		end
	end

	if modeId == "ffa" then
		ffaFillDeadline = nil
		updateFfaDeadline()
	end

	return matched
end

local function startMatch(players, modeId)
	if #players == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	for _, player in players do
		HubService.leaveForArena(player)
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	bindables.MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
end

function MatchmakingService.tryStartMatches()
	if MatchStateService.isArenaBusy() then
		for modeId in queues do
			broadcastQueueUpdates(modeId)
		end
		return
	end

	local priority = { "training", "pvp", "ffa" }
	for _, modeId in priority do
		if canStartMode(modeId) then
			local players = popPlayers(modeId)
			if #players > 0 then
				startMatch(players, modeId)
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	ensureInit()
	if not isValidMode(modeId) then
		return false
	end
	if MatchStateService.isArenaBusy() and HubService.getPhase(player) == "arena" then
		return false
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		joinTime = os.clock(),
	}

	updateFfaDeadline()
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	MatchmakingService.tryStartMatches()
	return true
end

function MatchmakingService.leaveQueue(player)
	ensureInit()
	local entry = playerQueue[player]
	if not entry then
		return
	end

	removeFromQueueList(entry.modeId, player)
	playerQueue[player] = nil
	clearFfaDeadlineIfEmpty()
	updateFfaDeadline()

	remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates(entry.modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	MatchmakingService.tryStartMatches()
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.init(remoteFolder, bindableFolder)
	if initialized then
		return
	end
	initialized = true
	remotes = remoteFolder
	bindables = bindableFolder

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	if heartbeatTask then
		task.cancel(heartbeatTask)
	end
	heartbeatTask = task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			MatchmakingService.tryStartMatches()
			for modeId in queues do
				broadcastQueueUpdates(modeId)
			end
		end
	end)
end

return MatchmakingService
