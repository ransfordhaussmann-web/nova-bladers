local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local gatherTokens = {}
local waitTokens = {}
local onMatchReady = nil
local matchInProgress = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	return modeId
end

local function buildQueuePayload(player, modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local config = getModeConfig(modeId)
	return {
		status = "waiting",
		modeId = modeId,
		label = config.label,
		position = position,
		total = #queue,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
	}
end

local function broadcastQueueState()
	for modeId, queue in queues do
		for _, player in queue do
			if player.Parent then
				Remotes.QueueState:FireClient(player, buildQueuePayload(player, modeId))
			end
		end
	end
end

local function canStartMode(modeId)
	local config = getModeConfig(modeId)
	return #queues[modeId] >= config.minPlayers
end

local function takePlayers(modeId)
	local config = getModeConfig(modeId)
	local count = math.min(#queues[modeId], config.maxPlayers)
	local players = {}

	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if player then
			playerQueue[player] = nil
			table.insert(players, player)
		end
	end

	return players
end

local function fireMatch(players, modeId)
	if #players == 0 or matchInProgress then
		for _, player in players do
			if player.Parent and not playerQueue[player] then
				MatchmakingService.joinQueue(player, modeId)
			end
		end
		return
	end

	matchInProgress = true
	gatherTokens[modeId] = (gatherTokens[modeId] or 0) + 1
	waitTokens[modeId] = (waitTokens[modeId] or 0) + 1

	for _, player in players do
		if player.Parent then
			Remotes.QueueState:FireClient(player, {
				status = "matched",
				modeId = modeId,
				label = getModeConfig(modeId).label,
				total = #players,
			})
		end
	end

	if onMatchReady then
		onMatchReady(players, modeId)
	end

	broadcastQueueState()
end

local function scheduleGather(modeId)
	gatherTokens[modeId] = (gatherTokens[modeId] or 0) + 1
	local token = gatherTokens[modeId]

	task.delay(MatchmakingConfig.GATHER_DELAY, function()
		if token ~= gatherTokens[modeId] then
			return
		end
		if matchInProgress or not canStartMode(modeId) then
			return
		end

		local players = takePlayers(modeId)
		fireMatch(players, modeId)
	end)
end

local function scheduleMaxWait(modeId)
	if MatchmakingConfig.MAX_WAIT_TIME <= 0 then
		return
	end

	waitTokens[modeId] = (waitTokens[modeId] or 0) + 1
	local token = waitTokens[modeId]

	task.delay(MatchmakingConfig.MAX_WAIT_TIME, function()
		if token ~= waitTokens[modeId] then
			return
		end
		if matchInProgress or #queues[modeId] == 0 then
			return
		end

		local config = getModeConfig(modeId)
		if #queues[modeId] >= config.minPlayers then
			scheduleGather(modeId)
		end
	end)
end

local function tryStartMatch(modeId)
	if matchInProgress or not canStartMode(modeId) then
		return
	end
	scheduleGather(modeId)
end

function MatchmakingService.setMatchReadyCallback(callback)
	onMatchReady = callback
end

function MatchmakingService.setMatchInProgress(active)
	matchInProgress = active
	if not active then
		for modeId, _ in queues do
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if matchInProgress then
		return false, "match_active"
	end
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] == modeId then
		return true
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local wasEmpty = #queues[modeId] == 1
	Remotes.QueueState:FireClient(player, buildQueuePayload(player, modeId))
	broadcastQueueState()

	if wasEmpty then
		scheduleMaxWait(modeId)
	end

	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return
	end

	waitTokens[modeId] = (waitTokens[modeId] or 0) + 1

	if player.Parent then
		Remotes.QueueState:FireClient(player, { status = "idle" })
	end

	broadcastQueueState()
end

function MatchmakingService.getQueueCounts()
	return {
		training = #queues.training,
		pvp = #queues.pvp,
		ffa = #queues.ffa,
	}
end

function MatchmakingService.getRecommendedMode()
	local online = #Players:GetPlayers()
	if online >= 3 then
		return "ffa"
	elseif online == 2 then
		return "pvp"
	end
	return "training"
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

return MatchmakingService
