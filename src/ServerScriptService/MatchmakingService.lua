local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local onArenaEnter = nil

local function initQueues()
	for modeId, _ in pairs(MatchModes.all()) do
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
end

local function countQueue(modeId)
	return #queues[modeId].players
end

local function isInQueue(player)
	return playerQueue[player] ~= nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue.players == 0 then
		queue.fillDeadline = nil
	elseif modeId == "ffa" and #queue.players < MatchModes.get("ffa").minPlayers then
		queue.fillDeadline = nil
	end
end

local function buildUpdatePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 1
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local secondsLeft = nil
	if queue.fillDeadline then
		secondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = MatchStateService.isBusy(),
		fillSecondsLeft = secondsLeft,
	}
end

local function broadcastQueue(modeId)
	for _, queuedPlayer in queues[modeId].players do
		if queuedPlayer.Parent then
			QueueUpdate:FireClient(queuedPlayer, buildUpdatePayload(queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId, _ in pairs(queues) do
		broadcastQueue(modeId)
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local size = #queue.players

	if size < mode.minPlayers then
		return false
	end
	if size >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end
	if modeId == "training" or modeId == "pvp" then
		return size >= mode.minPlayers
	end
	return false
end

local function takePlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue.players, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue.players, 1)
		if nextPlayer then
			playerQueue[nextPlayer] = nil
			table.insert(matchPlayers, nextPlayer)
		end
	end

	queue.fillDeadline = nil
	return matchPlayers
end

local function tryLaunchMatch(modeId)
	if not canStartMode(modeId) then
		return false
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return false
	end

	if MatchStateService.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = matchPlayers,
		}
		for _, player in matchPlayers do
			if player.Parent then
				QueueUpdate:FireClient(player, {
					inQueue = true,
					modeId = modeId,
					modeLabel = MatchModes.get(modeId).label,
					pending = true,
					arenaBusy = true,
					queueSize = #matchPlayers,
				})
			end
		end
		return true
	end

	MatchStateService.setBusy(true)
	for _, player in matchPlayers do
		if player.Parent then
			QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
	if onArenaEnter then
		for _, player in matchPlayers do
			onArenaEnter(player)
		end
	end
	MatchReady:Fire(matchPlayers)
	return true
end

local function updateFillDeadline(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local size = #queue.players

	if modeId == "ffa" and size >= mode.minPlayers and size < mode.maxPlayers then
		if not queue.fillDeadline then
			queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		end
	else
		queue.fillDeadline = nil
	end
end

local function scanQueues()
	for modeId, _ in pairs(queues) do
		updateFillDeadline(modeId)
		tryLaunchMatch(modeId)
	end
	broadcastAllQueues()
end

function MatchmakingService.start(handlers)
	onArenaEnter = handlers.onArenaEnter
	initQueues()

	MatchStateService.onArenaIdle(function()
		if pendingMatch then
			local match = pendingMatch
			pendingMatch = nil
			MatchStateService.setBusy(true)
			if onArenaEnter then
				for _, player in match.players do
					if player.Parent then
						onArenaEnter(player)
					end
				end
			end
			local readyPlayers = {}
			for _, player in match.players do
				if player.Parent then
					table.insert(readyPlayers, player)
				end
			end
			if #readyPlayers > 0 then
				for _, player in readyPlayers do
					QueueUpdate:FireClient(player, { inQueue = false })
				end
				MatchReady:Fire(readyPlayers)
			else
				MatchStateService.setBusy(false)
			end
			return
		end
		scanQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for modeId, _ in pairs(queues) do
				if queues[modeId].fillDeadline and os.clock() >= queues[modeId].fillDeadline then
					tryLaunchMatch(modeId)
				end
			end
			broadcastAllQueues()
		end
	end)

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		if not MatchModes.get(modeId) then
			return
		end
		if isInQueue(player) then
			removeFromQueue(player)
		end

		table.insert(queues[modeId].players, player)
		playerQueue[player] = modeId
		updateFillDeadline(modeId)
		tryLaunchMatch(modeId)
		broadcastQueue(modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		if not isInQueue(player) then
			return
		end
		local modeId = playerQueue[player]
		removeFromQueue(player)
		QueueUpdate:FireClient(player, { inQueue = false })
		broadcastQueue(modeId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if pendingMatch then
			for i, pendingPlayer in pendingMatch.players do
				if pendingPlayer == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			if #pendingMatch.players == 0 then
				pendingMatch = nil
				MatchStateService.setBusy(false)
			end
		end
		if isInQueue(player) then
			local modeId = playerQueue[player]
			removeFromQueue(player)
			broadcastQueue(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if isInQueue(player) then
		removeFromQueue(player)
	end
	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	updateFillDeadline(modeId)
	tryLaunchMatch(modeId)
	broadcastQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not isInQueue(player) then
		return
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
end

function MatchmakingService.notifyMatchEnded()
	MatchStateService.setBusy(false)
end

return MatchmakingService
