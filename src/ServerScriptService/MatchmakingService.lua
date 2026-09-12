local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingBridge = require(ReplicatedStorage.NovaBladers.MatchmakingBridge)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaBusy = false
local ffaFillToken = 0
local remotes = nil
local matchReadyBindable = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local cleaned = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(cleaned, player)
		end
	end
	queues[modeId] = cleaned
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local config = getModeConfig(modeId)
	if not config then
		return { inQueue = false }
	end

	pruneQueue(modeId)
	local current = countValidPlayers(queues[modeId])
	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif current >= config.minPlayers then
		status = "ready"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		current = current,
		needed = config.minPlayers,
		max = config.maxPlayers,
		status = status,
	}
end

local function broadcastQueueUpdate()
	for player, _ in playerQueue do
		if player.Parent and remotes then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function sendQueueUpdate(player)
	if remotes and player.Parent then
		remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function takePlayers(modeId, count)
	pruneQueue(modeId)
	local queue = queues[modeId]
	local taken = {}
	local remaining = {}

	for _, player in queue do
		if #taken < count and player.Parent then
			table.insert(taken, player)
			playerQueue[player] = nil
		else
			table.insert(remaining, player)
		end
	end

	queues[modeId] = remaining
	return taken
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function tryStartMatch(modeId)
	if arenaBusy then
		broadcastQueueUpdate()
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	pruneQueue(modeId)
	local queue = queues[modeId]
	if countValidPlayers(queue) < config.minPlayers then
		broadcastQueueUpdate()
		return
	end

	local playerCount = math.min(countValidPlayers(queue), config.maxPlayers)
	local players = takePlayers(modeId, playerCount)

	if #players < config.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		broadcastQueueUpdate()
		return
	end

	if modeId == "ffa" then
		cancelFfaFillTimer()
	end

	arenaBusy = true
	broadcastQueueUpdate()

	if matchReadyBindable then
		matchReadyBindable:Fire(players, modeId)
	end
	MatchmakingBridge.onMatchStarted(players, modeId)
end

local function scheduleFfaFill()
	cancelFfaFillTimer()
	local token = ffaFillToken
	local timeout = MatchmakingConfig.MODES.ffa.fillTimeout

	task.delay(timeout, function()
		if token ~= ffaFillToken or arenaBusy then
			return
		end
		pruneQueue("ffa")
		if countValidPlayers(queues.ffa) >= MatchmakingConfig.MODES.ffa.minPlayers then
			tryStartMatch("ffa")
		end
	end)
end

local function onQueueChanged(modeId)
	if modeId == "ffa" then
		pruneQueue("ffa")
		local count = countValidPlayers(queues.ffa)
		local config = MatchmakingConfig.MODES.ffa

		if count >= config.maxPlayers then
			tryStartMatch("ffa")
		elseif count >= config.minPlayers then
			scheduleFfaFill()
			broadcastQueueUpdate()
		else
			cancelFfaFillTimer()
			broadcastQueueUpdate()
		end
		return
	end

	tryStartMatch(modeId)
end

function MatchmakingService.init(remotesFolder, bindablesFolder)
	remotes = remotesFolder
	matchReadyBindable = bindablesFolder.MatchReady
end

function MatchmakingService.joinQueue(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end

	if playerQueue[player] then
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	removePlayerFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removePlayerFromQueue(player)

	if modeId == "ffa" then
		cancelFfaFillTimer()
	end

	if remotes then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdate()

	if modeId == "ffa" then
		onQueueChanged("ffa")
	end
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	broadcastQueueUpdate()

	for modeId, _ in MatchmakingConfig.MODES do
		onQueueChanged(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.getActiveModeForServer()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
