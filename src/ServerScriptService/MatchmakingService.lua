local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local remotes = nil
local onMatchReady = nil
local fillTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getQueuedPlayers(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	queues[modeId] = list
	return list
end

local function removeFromAllQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return nil
	end

	playerQueue[player] = nil
	local queue = queues[previousMode]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if fillTokens[previousMode] then
		fillTokens[previousMode] = nil
	end

	return previousMode
end

local function buildUpdatePayload(modeId, player)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end

	local queue = getQueuedPlayers(modeId)
	local position = 0
	for i, queued in queue do
		if queued == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if #queue >= mode.minPlayers and arenaBusy then
		status = "pending"
	elseif #queue >= mode.minPlayers then
		status = "ready"
	end

	local fillSecondsLeft = nil
	local token = fillTokens[modeId]
	if token and token.deadline then
		fillSecondsLeft = math.max(0, math.ceil(token.deadline - os.clock()))
	end

	return {
		modeId = modeId,
		label = mode.label,
		position = position,
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueuedPlayers(modeId)
	for _, player in queue do
		if player.Parent and remotes then
			remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
end

local function canStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueuedPlayers(modeId)
	if #queue < mode.minPlayers or arenaBusy then
		return false
	end

	if modeId == "ffa" and mode.fillTimeout and #queue < mode.maxPlayers then
		local token = fillTokens[modeId]
		if not token then
			return false
		end
		if os.clock() < token.deadline then
			return false
		end
	end

	return true
end

local function popPlayersForMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueuedPlayers(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for i = 1, count do
		local player = queue[i]
		table.insert(matchPlayers, player)
		playerQueue[player] = nil
	end

	queues[modeId] = {}
	fillTokens[modeId] = nil
	return matchPlayers
end

local function tryStartMatch(modeId)
	if not canStartMatch(modeId) then
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	arenaBusy = true
	broadcastAllQueues()

	if onMatchReady then
		onMatchReady(matchPlayers, modeId)
	end
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	local queue = getQueuedPlayers(modeId)
	if #queue < mode.minPlayers or #queue >= mode.maxPlayers then
		fillTokens[modeId] = nil
		return
	end

	if fillTokens[modeId] then
		return
	end

	local token = { id = (fillTokens._seq or 0) + 1 }
	fillTokens._seq = token.id
	token.deadline = os.clock() + mode.fillTimeout
	fillTokens[modeId] = token

	task.spawn(function()
		while fillTokens[modeId] == token do
			broadcastQueue(modeId)
			if os.clock() >= token.deadline then
				break
			end
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		end
		if fillTokens[modeId] == token then
			tryStartMatch(modeId)
		end
	end)
end

local function tryStartImmediateModes(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueuedPlayers(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		scheduleFillTimeout(modeId)
		if #queue >= mode.maxPlayers then
			tryStartMatch(modeId)
		end
		return
	end

	tryStartMatch(modeId)
end

function MatchmakingService.init(remoteFolder, matchReadyCallback)
	remotes = remoteFolder
	onMatchReady = matchReadyCallback
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		broadcastQueue(modeId)
		return true, "already_queued"
	end

	removeFromAllQueues(player)

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueuedPlayers(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	tryStartImmediateModes(modeId)
	return true, "joined"
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		broadcastQueue(modeId)
	end
	return modeId
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	broadcastAllQueues()

	for modeId in MatchmakingConfig.MODES do
		tryStartImmediateModes(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		broadcastQueue(modeId)
		tryStartImmediateModes(modeId)
	end
end

return MatchmakingService
