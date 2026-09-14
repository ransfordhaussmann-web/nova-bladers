local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
	return modeId
end

local function buildUpdatePayload(player, modeId, status)
	local mode = MatchModes.getById(modeId)
	local queue = queues[modeId]
	local position = 0

	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local message
	if status == "pending" then
		message = MatchmakingConfig.PENDING_MESSAGE
	elseif status == "waiting" then
		if modeId == "training" then
			message = "Starte Training..."
		elseif modeId == "pvp" then
			message = string.format("Warte auf Gegner (%d/%d)", #queue, mode.minPlayers)
		else
			message = string.format("Warte auf Spieler (%d/%d)", #queue, mode.minPlayers)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		message = message,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	if #queue == 0 then
		return
	end

	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	for _, player in queue do
		if player.Parent and HubService.getPhase(player) == "hub" then
			QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function pullPlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local pulled = {}
	local amount = math.min(count, #queue)

	for _ = 1, amount do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(pulled, player)
		end
	end

	return pulled
end

local function cancelFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	local mode = MatchModes.getById(modeId)
	local queue = queues[modeId]

	if #queue < mode.minPlayers then
		return false
	end

	local count = math.min(#queue, mode.maxPlayers)
	local players = pullPlayersFromQueue(modeId, count)

	if #players < mode.minPlayers then
		for index = #players, 1, -1 do
			local player = players[index]
			table.insert(queue, 1, player)
			playerMode[player] = modeId
		end
		return false
	end

	cancelFillTimer(modeId)

	for _, player in players do
		QueueUpdate:FireClient(player, {
			status = "matched",
			modeId = modeId,
			modeLabel = mode.label,
		})
	end

	broadcastAllQueues()
	MatchReady:Fire(players, modeId)
	return true
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.getById(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil

		local queue = queues[modeId]
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.getById(modeId)
	local queueSize = getQueueSize(modeId)

	if queueSize >= mode.maxPlayers then
		cancelFillTimer(modeId)
		tryStartMatch(modeId)
		return
	end

	if queueSize >= mode.minPlayers then
		if mode.fillTimeout > 0 then
			scheduleFillTimer(modeId)
		else
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not queues[modeId] or not MatchModes.isValid(modeId) then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	if playerMode[player] == modeId then
		return
	end

	local previousMode = removeFromQueue(player)
	if previousMode then
		broadcastQueue(previousMode)
	end

	local mode = MatchModes.getById(modeId)
	if getQueueSize(modeId) >= mode.maxPlayers then
		return
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
	broadcastQueue(modeId)
	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return
	end

	QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueue(modeId)

	local mode = MatchModes.getById(modeId)
	if getQueueSize(modeId) < mode.minPlayers then
		cancelFillTimer(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFree()
	broadcastAllQueues()

	for _, modeId in { "training", "pvp", "ffa" } do
		local mode = MatchModes.getById(modeId)
		if getQueueSize(modeId) >= mode.minPlayers then
			if mode.fillTimeout > 0 and getQueueSize(modeId) < mode.maxPlayers then
				scheduleFillTimer(modeId)
			elseif tryStartMatch(modeId) then
				break
			end
		end
	end
end

function MatchmakingService.start()
	MatchStateService.onArenaBusyChanged(function(busy)
		if busy then
			broadcastAllQueues()
		else
			MatchmakingService.onArenaFree()
		end
	end)

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
end

return MatchmakingService
