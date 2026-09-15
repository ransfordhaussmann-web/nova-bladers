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
local playerQueues = {}
local fillTokens = {}
local started = false

local function initQueues()
	for modeId in MatchModes do
		queues[modeId] = {}
	end
end

local function findQueuePosition(modeId, player)
	for i, p in queues[modeId] do
		if p == player then
			return i
		end
	end
	return nil
end

local function buildPayload(modeId, player)
	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = playerQueues[player] == modeId,
		arenaBusy = MatchStateService.isArenaBusy(),
		position = findQueuePosition(modeId, player),
		pending = MatchStateService.isArenaBusy() and #queue >= mode.minPlayers,
	}
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			QueueUpdate:FireClient(player, buildPayload(modeId, player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueues[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueues[player] = nil
	broadcastQueueUpdate(modeId)
end

local function takePlayersFromQueue(modeId, count)
	local matchPlayers = {}
	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if not player then
			break
		end
		playerQueues[player] = nil
		table.insert(matchPlayers, player)
	end
	return matchPlayers
end

local function startMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end

	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = takePlayersFromQueue(modeId, count)
	if #matchPlayers < mode.minPlayers then
		for _, player in matchPlayers do
			table.insert(queues[modeId], player)
			playerQueues[player] = modeId
		end
		return false
	end

	fillTokens[modeId] = nil
	MatchStateService.setArenaBusy()
	MatchReady:Fire(matchPlayers, modeId)
	broadcastQueueUpdate(modeId)
	return true
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes[modeId]
	if not mode.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTokens[modeId] = nil

		local queue = queues[modeId]
		if #queue >= mode.minPlayers then
			startMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes[modeId]
	local queue = queues[modeId]

	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		startMatch(modeId)
	elseif mode.fillTimeout then
		if not fillTokens[modeId] then
			scheduleFillTimer(modeId)
		end
	else
		startMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes[modeId] then
		return false
	end
	if playerQueues[player] then
		if playerQueues[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueues[player] = modeId

	QueueUpdate:FireClient(player, buildPayload(modeId, player))
	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueues[player] then
		return
	end
	removeFromQueue(player)
	QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueues[player]
end

function MatchmakingService.onArenaFree()
	MatchStateService.setArenaFree()

	for modeId in MatchModes do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_CHECK_INTERVAL)
			if MatchStateService.isArenaBusy() then
				continue
			end
			for modeId in MatchModes do
				local mode = MatchModes[modeId]
				if #queues[modeId] >= mode.minPlayers then
					evaluateQueue(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
