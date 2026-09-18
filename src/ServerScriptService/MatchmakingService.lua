local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromAllQueues(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil
	if fillTimers[modeId] and #queue < MatchModes.get(modeId).minPlayers then
		fillTimers[modeId] = nil
	end
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function clearQueueUpdate(player)
	sendQueueUpdate(player, { inQueue = false })
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif #queue >= mode.minPlayers then
		status = "ready"
	end

	local fillSecondsLeft
	local fillStarted = fillTimers[modeId]
	if fillStarted and mode.fillTimeout > 0 then
		fillSecondsLeft = math.max(0, math.ceil(mode.fillTimeout - (os.clock() - fillStarted)))
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		status = status,
		position = position,
		queueSize = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player, buildQueuePayload(modeId, player))
	end
end

local function popQueue(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	fillTimers[modeId] = nil
	return picked
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

	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	if mode.fillTimeout > 0 then
		if not fillTimers[modeId] then
			fillTimers[modeId] = os.clock()
			broadcastQueue(modeId)
			return
		end

		local elapsed = os.clock() - fillTimers[modeId]
		local atMax = #queue >= mode.maxPlayers
		if not atMax and elapsed < mode.fillTimeout then
			broadcastQueue(modeId)
			return
		end
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = popQueue(modeId, playerCount)
	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)

	for _, player in players do
		sendQueueUpdate(player, {
			inQueue = true,
			mode = modeId,
			modeLabel = mode.label,
			status = "starting",
			queueSize = 0,
			needed = mode.minPlayers,
		})
	end

	MatchReady:Fire(players, modeId)
end

local function processQueues()
	for _, modeId in MatchModes.ids() do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	removeFromAllQueues(player)
	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId
	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		clearQueueUpdate(player)
		return
	end

	removeFromAllQueues(player)
	clearQueueUpdate(player)
	broadcastQueue(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		processQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for modeId, startedAt in fillTimers do
				local mode = MatchModes.get(modeId)
				if mode and os.clock() - startedAt >= mode.fillTimeout then
					tryStartMode(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
