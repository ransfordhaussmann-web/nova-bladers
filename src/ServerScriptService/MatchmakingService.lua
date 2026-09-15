local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local onMatchStarting = nil

local function getQueueNames(modeId)
	local names = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function clearQueueState(player)
	Remotes.QueueUpdate:FireClient(player, {
		modeId = nil,
		status = "idle",
		queueSize = 0,
		required = 0,
		maxPlayers = 0,
		players = {},
		fillTimeLeft = nil,
	})
end

local function buildQueuePayload(modeId, fillTimeLeft)
	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	local queueSize = #queue
	local arenaBusy = MatchStateService.isArenaBusy()

	local status = "waiting"
	if arenaBusy then
		status = "pending_arena"
	elseif queueSize >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		status = status,
		queueSize = queueSize,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = getQueueNames(modeId),
		fillTimeLeft = fillTimeLeft,
		modeLabel = mode.label,
	}
end

local function broadcastQueueUpdate(modeId, fillTimeLeft)
	local payload = buildQueuePayload(modeId, fillTimeLeft)
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
	end

	if not silent then
		clearQueueState(player)
		broadcastQueueUpdate(modeId)
	end
end

local function pullPlayers(modeId, count)
	local players = {}
	local queue = queues[modeId]
	local take = math.min(count, #queue)

	for index = 1, take do
		table.insert(players, queue[index])
	end

	for _, player in players do
		removeFromQueue(player, true)
	end

	for _, player in players do
		clearQueueState(player)
	end

	broadcastQueueUpdate(modeId)
	return players
end

local function canStartMatch()
	return not MatchStateService.isArenaBusy()
end

local function launchMatch(players, modeId)
	if #players == 0 then
		return
	end

	if onMatchStarting then
		onMatchStarting(players, modeId)
	end

	MatchReady:Fire(players, modeId)
end

local function tryStartInstantMode(modeId)
	if not canStartMatch() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes[modeId]
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	local players = pullPlayers(modeId, mode.maxPlayers)
	launchMatch(players, modeId)
end

local function startFFAFillTimer()
	local mode = MatchModes.ffa
	if #queues.ffa < mode.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.spawn(function()
		local deadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT

		while os.clock() < deadline do
			if token ~= ffaFillToken then
				return
			end

			local queue = queues.ffa
			if #queue < mode.minPlayers then
				return
			end

			if canStartMatch() and #queue >= mode.maxPlayers then
				break
			end

			if not canStartMatch() then
				broadcastQueueUpdate("ffa")
				task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
				continue
			end

			local timeLeft = math.max(0, math.ceil(deadline - os.clock()))
			broadcastQueueUpdate("ffa", timeLeft)
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
		end

		if token ~= ffaFillToken then
			return
		end

		if not canStartMatch() then
			broadcastQueueUpdate("ffa")
			return
		end

		local queue = queues.ffa
		if #queue >= mode.minPlayers then
			local players = pullPlayers("ffa", mode.maxPlayers)
			launchMatch(players, "ffa")
		end
	end)
end

local function processQueues()
	for modeId, mode in MatchModes do
		if modeId == "ffa" then
			if #queues.ffa >= mode.minPlayers then
				startFFAFillTimer()
			else
				broadcastQueueUpdate("ffa")
			end
		else
			tryStartInstantMode(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return
	end

	if playerQueue[player] == modeId then
		broadcastQueueUpdate(modeId)
		return
	end

	removeFromQueue(player, true)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)

	if modeId == "ffa" then
		if #queues.ffa >= MatchModes.ffa.minPlayers then
			startFFAFillTimer()
		end
	else
		tryStartInstantMode(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player, false)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.registerMatchStarting(callback)
	onMatchStarting = callback
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player, true)
	end)

	MatchStateService.onArenaFree(processQueues)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
