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
local fillTimers = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function countValid(queue)
	local n = 0
	for _, player in queue do
		if player.Parent then
			n += 1
		end
	end
	return n
end

local function compactQueue(modeId)
	local queue = getQueue(modeId)
	local compacted = {}
	for _, player in queue do
		if player.Parent then
			table.insert(compacted, player)
		end
	end
	queues[modeId] = compacted
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	compactQueue(modeId)

	local names = {}
	for _, queued in queue do
		table.insert(names, queued.DisplayName)
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = names,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	compactQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromAllQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return nil
	end

	playerQueue[player] = nil
	compactQueue(previousMode)
	local queue = getQueue(previousMode)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	local mode = MatchModes.get(previousMode)
	if mode and mode.fillTimeout and countValid(queue) < mode.minPlayers then
		clearFillTimer(previousMode)
	end

	broadcastQueueUpdate(previousMode)
	return previousMode
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	compactQueue(modeId)
	local count = #queue

	if count >= mode.maxPlayers then
		return true, queue
	end

	if count >= mode.minPlayers then
		if mode.fillTimeout then
			return fillTimers[modeId] ~= nil, queue
		end
		return true, queue
	end

	return false, queue
end

local function launchMatch(_modeId, roster)
	MatchReady:Fire(_modeId, roster)
end

local function takeRoster(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	compactQueue(modeId)

	local roster = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(roster, queue[i])
	end

	for _, player in roster do
		playerQueue[player] = nil
		for i, queued in queue do
			if queued == player then
				table.remove(queue, i)
				break
			end
		end
	end

	clearFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	return roster
end

local function tryStartMatch(modeId)
	local ready, queue = canStartMatch(modeId)
	if not ready or #queue == 0 then
		return
	end

	local mode = MatchModes.get(modeId)
	local roster = takeRoster(modeId)

	local startNow = function()
		local valid = {}
		for _, player in roster do
			if player.Parent then
				table.insert(valid, player)
			end
		end
		if #valid == 0 then
			return
		end
		launchMatch(modeId, valid)
	end

	if MatchStateService.isArenaBusy() then
		for _, player in roster do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					modeId = modeId,
					modeLabel = mode.label,
					players = #roster,
					minPlayers = mode.minPlayers,
					maxPlayers = mode.maxPlayers,
					status = "pending",
					inQueue = true,
				})
			end
		end
		MatchStateService.whenArenaFree(startNow)
	else
		startNow()
	end
end

local function maybeStartFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	local queue = getQueue(modeId)
	compactQueue(modeId)
	local count = #queue

	if count < mode.fillMinPlayers or count >= mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		compactQueue(modeId)
		if #getQueue(modeId) >= mode.fillMinPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true
	end

	removeFromAllQueues(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and not mode.fillTimeout then
		tryStartMatch(modeId)
	else
		maybeStartFillTimer(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			inQueue = false,
			status = "left",
		})
	end
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromAllQueues(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
