local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerToMode = {}
local remotes = nil
local matchReadyEvent = nil
local leaveHubCallback = nil
local tickRunning = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { order = {}, fillDeadline = nil }
	end
	return queues[modeId]
end

local function getQueuePosition(modeId, player)
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue.order do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes[modeId]
	if not mode then
		return { status = "none" }
	end

	local queue = getQueue(modeId)
	local position = getQueuePosition(modeId, player)
	local arenaBusy = MatchStateService.isArenaOccupied()

	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif #queue.order >= mode.maxPlayers then
		status = "ready"
	elseif mode.minPlayers == mode.maxPlayers and #queue.order >= mode.minPlayers and not arenaBusy then
		status = "ready"
	end

	local fillSecondsLeft = nil
	if queue.fillDeadline and mode.fillTimeout then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue.order,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSecondsLeft = fillSecondsLeft,
		arenaBusy = arenaBusy,
	}
end

local function sendQueueUpdate(player)
	if not remotes or not player.Parent then
		return
	end

	local modeId = playerToMode[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { status = "none" })
		return
	end

	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastQueueUpdates(modeId)
	local queue = getQueue(modeId)
	for _, player in queue.order do
		sendQueueUpdate(player)
	end
end

local function broadcastAllQueues()
	for modeId in MatchModes do
		broadcastQueueUpdates(modeId)
	end
end

local function canStartMatch(modeId)
	if MatchStateService.isArenaOccupied() then
		return false
	end

	local mode = MatchModes[modeId]
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	local count = #queue.order

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.minPlayers == mode.maxPlayers then
		return count >= mode.minPlayers
	end

	if mode.fillTimeout and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end

	return false
end

local function startFillTimer(modeId)
	local mode = MatchModes[modeId]
	if not mode or not mode.fillTimeout then
		return
	end

	local queue = getQueue(modeId)
	if #queue.order < mode.minPlayers or queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + mode.fillTimeout
	broadcastQueueUpdates(modeId)
end

local function tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local mode = MatchModes[modeId]
	local queue = getQueue(modeId)
	local takeCount = math.min(#queue.order, mode.maxPlayers)
	local matchedPlayers = {}

	for _ = 1, takeCount do
		local nextPlayer = table.remove(queue.order, 1)
		if nextPlayer and nextPlayer.Parent then
			playerToMode[nextPlayer] = nil
			table.insert(matchedPlayers, nextPlayer)
		end
	end

	queue.fillDeadline = nil

	if #matchedPlayers == 0 then
		return
	end

	MatchStateService.setArenaOccupied(true)

	for _, player in matchedPlayers do
		if leaveHubCallback then
			leaveHubCallback(player)
		end
		if remotes then
			remotes.QueueUpdate:FireClient(player, {
				status = "starting",
				modeId = modeId,
				modeLabel = mode.label,
			})
		end
	end

	if matchReadyEvent then
		matchReadyEvent:Fire({
			players = matchedPlayers,
			modeId = modeId,
		})
	end

	broadcastQueueUpdates(modeId)
end

local function tryStartAllQueues()
	for modeId in MatchModes do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerToMode[player]
	if not modeId then
		return
	end

	playerToMode[player] = nil

	local queue = getQueue(modeId)
	for index, queuedPlayer in queue.order do
		if queuedPlayer == player then
			table.remove(queue.order, index)
			break
		end
	end

	if #queue.order < MatchModes[modeId].minPlayers then
		queue.fillDeadline = nil
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue.order, player)
	playerToMode[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	startFillTimer(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.onArenaFree()
	MatchStateService.setArenaOccupied(false)
	broadcastAllQueues()
	tryStartAllQueues()
end

function MatchmakingService.getPlayerMode(player)
	return playerToMode[player]
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyEvent = options.bindables.MatchReady
	leaveHubCallback = options.leaveHub

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if not tickRunning then
		tickRunning = true
		task.spawn(function()
			while true do
				task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
				for modeId in MatchModes do
					local queue = getQueue(modeId)
					if queue.fillDeadline and canStartMatch(modeId) then
						tryStartMatch(modeId)
					elseif queue.fillDeadline then
						broadcastQueueUpdates(modeId)
					end
				end
			end
		end)
	end
end

return MatchmakingService
