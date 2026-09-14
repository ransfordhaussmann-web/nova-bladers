local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local ffaFillEndsAt = 0
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromAllQueues(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function pruneQueue(queue)
	local cleaned = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] then
			table.insert(cleaned, player)
		end
	end
	return cleaned
end

local function refreshQueue(modeId)
	local pruned = pruneQueue(getQueue(modeId))
	queues[modeId] = pruned
	return pruned
end

local function countValid(modeId)
	return #refreshQueue(modeId)
end

local function queueStatus()
	if GameMatchState.isBusy() then
		return "pending"
	end
	return "waiting"
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local inQueue = countValid(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = inQueue,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = queueStatus(),
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function broadcastQueueUpdate()
	for player, entry in playerQueue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, entry.modeId))
		end
	end
end

local function notifyLeft(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function takePlayers(modeId, count)
	local queue = refreshQueue(modeId)
	local taken = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[i]
		table.insert(taken, player)
		playerQueue[player] = nil
	end

	local remaining = {}
	for i = #taken + 1, #queue do
		table.insert(remaining, queue[i])
	end
	queues[modeId] = remaining

	for _, player in taken do
		notifyLeft(player)
	end

	return taken
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end
	return countValid(modeId) >= mode.minPlayers
end

local function ffaStillFilling()
	local mode = MatchModes.get("ffa")
	local count = countValid("ffa")
	if count >= mode.maxPlayers then
		return false
	end
	if count < mode.minPlayers then
		return true
	end
	return os.clock() < ffaFillEndsAt
end

local function launchMatch(modeId, playerCount)
	local mode = MatchModes.get(modeId)
	local players = takePlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	if modeId == "ffa" then
		ffaFillToken += 1
		ffaFillEndsAt = 0
	end

	GameMatchState.setBusy(true)
	broadcastQueueUpdate()

	task.delay(MatchmakingConfig.MATCH_FORM_DELAY, function()
		if Bindables.MatchReady then
			Bindables.MatchReady:Fire(players, modeId)
		end
	end)
end

local function tryStartMatch()
	if GameMatchState.isBusy() then
		broadcastQueueUpdate()
		return
	end

	local candidates = {}
	for _, mode in MatchModes.all() do
		if canStartMode(mode.id) and not (mode.id == "ffa" and ffaStillFilling()) then
			table.insert(candidates, mode)
		end
	end

	table.sort(candidates, function(a, b)
		return a.priority > b.priority
	end)

	local chosen = candidates[1]
	if not chosen then
		broadcastQueueUpdate()
		return
	end

	local queueSize = countValid(chosen.id)
	local playerCount = math.min(queueSize, chosen.maxPlayers)
	launchMatch(chosen.id, playerCount)
end

local function scheduleFfaFillCheck()
	ffaFillToken += 1
	local token = ffaFillToken
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		tryStartMatch()
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	broadcastQueueUpdate()

	if modeId == "ffa" then
		local mode = MatchModes.get("ffa")
		local count = countValid("ffa")
		if count == mode.minPlayers then
			ffaFillEndsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			scheduleFfaFillCheck()
		elseif count >= mode.maxPlayers then
			tryStartMatch()
		end
	else
		tryStartMatch()
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromAllQueues(player)
	notifyLeft(player)
	broadcastQueueUpdate()
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	broadcastQueueUpdate()
	tryStartMatch()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
	broadcastQueueUpdate()
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.start(hubHandlers)
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if hubHandlers.getPhase(player) ~= "hub" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if Bindables.ArenaFree then
		Bindables.ArenaFree.Event:Connect(function()
			MatchmakingService.onArenaFree()
		end)
	end

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			if started then
				broadcastQueueUpdate()
			end
		end
	end)

	started = true
	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
