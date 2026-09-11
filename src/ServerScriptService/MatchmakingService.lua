local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local remotes
local bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local pending = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local ffaFillToken = 0
local ffaFillEndsAt = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidModeId(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromList(list, player)
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, index)
			return true
		end
	end
	return false
end

local function countQueued(modeId)
	return #queues[modeId] + #pending[modeId]
end

local function buildUpdatePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local config = getModeConfig(entry.modeId)
	local queued = countQueued(entry.modeId)
	local payload = {
		inQueue = true,
		pending = entry.pending,
		modeId = entry.modeId,
		modeLabel = config.label,
		queued = queued,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
	}

	if entry.modeId == "ffa" and ffaFillEndsAt and not entry.pending then
		payload.fillSeconds = math.max(0, math.ceil(ffaFillEndsAt - os.clock()))
	end

	return payload
end

local function broadcastQueueUpdate(player)
	if player.Parent and remotes then
		remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	end
end

local function broadcastModeQueue(modeId)
	for player, entry in playerEntry do
		if entry.modeId == modeId and player.Parent then
			broadcastQueueUpdate(player)
		end
	end
end

local function clearPlayer(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	removeFromList(queues[entry.modeId], player)
	removeFromList(pending[entry.modeId], player)
	playerEntry[player] = nil
end

local function popPlayers(modeId, maxCount)
	local list = MatchState.isArenaBusy() and pending[modeId] or queues[modeId]
	local picked = {}
	local limit = math.min(maxCount, #list)

	for _ = 1, limit do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(picked, player)
		end
	end

	return picked
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
	ffaFillEndsAt = nil
end

local function startMatch(players, modeId)
	if #players == 0 then
		return
	end

	cancelFfaFillTimer()
	MatchState.setArenaBusy(true)

	for _, player in players do
		if HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
		broadcastQueueUpdate(player)
	end

	bindables.MatchReady:Fire(players, modeId)
end

local function tryStartTraining()
	if MatchState.isArenaBusy() then
		return
	end

	local config = getModeConfig("training")
	if #queues.training >= config.minPlayers then
		startMatch(popPlayers("training", 1), "training")
	end
end

local function tryStartPvp()
	if MatchState.isArenaBusy() then
		return
	end

	local config = getModeConfig("pvp")
	if #queues.pvp >= config.minPlayers then
		startMatch(popPlayers("pvp", config.maxPlayers), "pvp")
	end
end

local function tryStartFfa()
	if MatchState.isArenaBusy() then
		return
	end

	local config = getModeConfig("ffa")
	local queueCount = #queues.ffa

	if queueCount >= config.maxPlayers then
		startMatch(popPlayers("ffa", config.maxPlayers), "ffa")
		return
	end

	if queueCount < config.minPlayers then
		cancelFfaFillTimer()
		return
	end

	if ffaFillEndsAt then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillEndsAt = os.clock() + config.fillTimeout
	broadcastModeQueue("ffa")

	task.spawn(function()
		while token == ffaFillToken and ffaFillEndsAt and os.clock() < ffaFillEndsAt do
			broadcastModeQueue("ffa")
			task.wait(1)
		end
	end)

	task.delay(config.fillTimeout, function()
		if token ~= ffaFillToken or MatchState.isArenaBusy() then
			return
		end

		ffaFillEndsAt = nil
		if #queues.ffa >= config.minPlayers then
			startMatch(popPlayers("ffa", config.maxPlayers), "ffa")
		end
	end)
end

local function tryStartAll()
	tryStartTraining()
	tryStartPvp()
	tryStartFfa()
end

local function flushPending()
	for modeId, list in pending do
		for _, player in list do
			table.insert(queues[modeId], player)
			if playerEntry[player] then
				playerEntry[player].pending = false
			end
		end
		table.clear(list)
		broadcastModeQueue(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidModeId(modeId) then
		return
	end
	if playerEntry[player] then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	local entry = {
		modeId = modeId,
		pending = MatchState.isArenaBusy(),
	}

	playerEntry[player] = entry

	if entry.pending then
		table.insert(pending[modeId], player)
	else
		table.insert(queues[modeId], player)
	end

	broadcastQueueUpdate(player)
	broadcastModeQueue(modeId)

	if not entry.pending then
		tryStartAll()
	end
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	clearPlayer(player)
	broadcastQueueUpdate(player)
	broadcastModeQueue(modeId)

	if modeId == "ffa" and #queues.ffa < getModeConfig("ffa").minPlayers then
		cancelFfaFillTimer()
		broadcastModeQueue("ffa")
	end
end

function MatchmakingService.onMatchEnded()
	MatchState.setArenaBusy(false)
	cancelFfaFillTimer()
	flushPending()
	tryStartAll()
end

function MatchmakingService.init(remoteFolder, bindableFolder)
	remotes = remoteFolder
	bindables = bindableFolder

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
