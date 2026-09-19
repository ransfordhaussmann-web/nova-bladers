local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(ReplicatedStorage.NovaBladers.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local initialized = false
local hubCallbacks = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
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

	playerQueue[player] = nil
	local mode = MatchModes.get(modeId)
	if mode and #queue < mode.minPlayers then
		fillTimers[modeId] = nil
	end
end

local function buildUpdatePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local pending = MatchStateService.isBusy()
	local status
	if pending then
		status = "pending"
	elseif #queue >= mode.minPlayers then
		status = "ready"
	elseif modeId == "ffa" and fillTimers[modeId] then
		status = "filling"
	else
		status = "waiting"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status,
		pending = pending,
		fillSecondsLeft = nil,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function popMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	fillTimers[modeId] = nil
	return matchPlayers
end

local function startMatch(modeId)
	local players = popMatchPlayers(modeId)
	if #players == 0 then
		return
	end

	MatchStateService.setBusy(true)
	broadcastAllQueues()
	MatchReady:Fire(players, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			startMatch(modeId)
			return
		end

		if fillTimers[modeId] then
			if os.clock() >= fillTimers[modeId] then
				startMatch(modeId)
			end
			return
		end

		fillTimers[modeId] = os.clock() + (mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT)
		broadcastQueue(modeId)
		return
	end

	startMatch(modeId)
end

local function processQueues()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastAllQueues()
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueue(modeId)
	tryStartMode(modeId)

	if hubCallbacks.onLeaveQueue then
		hubCallbacks.onLeaveQueue(player)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(callbacks)
	if initialized then
		return
	end
	initialized = true
	hubCallbacks = callbacks or {}

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	MatchStateService.onArenaFree(function()
		processQueues()
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if hubCallbacks and hubCallbacks.onJoinQueue then
			hubCallbacks.onJoinQueue(player, modeId)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId in queues do
				if fillTimers[modeId] and os.clock() >= fillTimers[modeId] then
					tryStartMode(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
