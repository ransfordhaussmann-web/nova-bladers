local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue == 0 and fillTimers[entry.modeId] then
		fillTimers[entry.modeId] = nil
	end
end

local function buildQueuePayload(player, status)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local fillTimer = fillTimers[entry.modeId]

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		playersInQueue = #queue,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or (if GameMatchState.isArenaBusy() then "pending" else "waiting"),
		fillCountdown = fillTimer and math.max(0, math.ceil(fillTimer.endsAt - os.clock())) or nil,
	}
end

local function broadcastQueueUpdate(modeId, status)
	for player, entry in playerQueue do
		if entry.modeId == modeId and player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, status))
		end
	end
end

local function broadcastAllQueueUpdates()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	local limit = math.min(count, #queue)

	for _ = 1, limit do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerQueue[player] = nil
		end
	end

	fillTimers[modeId] = nil
	return taken
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	GameMatchState.setArenaBusy(true)

	for _, player in playerList do
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if GameMatchState.isArenaBusy() then
		broadcastQueueUpdate(modeId, "pending")
		return
	end

	if mode.fillTimeout > 0 and not fillTimers[modeId] then
		fillTimers[modeId] = { endsAt = os.clock() + mode.fillTimeout }
		broadcastQueueUpdate(modeId, "filling")
		return
	end

	if mode.fillTimeout > 0 and fillTimers[modeId] then
		if os.clock() < fillTimers[modeId].endsAt then
			return
		end
	end

	local count = math.min(#queue, mode.maxPlayers)
	startMatch(modeId, takePlayers(modeId, count))
end

local function processQueues()
	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = { modeId = modeId, joinedAt = os.clock() }

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	processQueues()

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)
	broadcastAllQueueUpdates()
	processQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	task.spawn(function()
		while true do
			processQueues()
			task.wait(MatchmakingConfig.QUEUE_TICK)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)
end

return MatchmakingService
