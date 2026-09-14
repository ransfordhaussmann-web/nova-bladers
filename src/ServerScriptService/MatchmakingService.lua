local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local remotes
local matchReadyBindable

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillDeadline = nil
local ffaFillToken = 0

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromAllQueues(player)
	local previousMode = playerMode[player]
	if not previousMode then
		return nil
	end

	local queue = getQueue(previousMode)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerMode[player] = nil

	if previousMode == "ffa" and #queues.ffa == 0 then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end

	return previousMode
end

local function getPlayerNames(queue)
	local names = {}
	for _, player in queue do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function getQueueStatus(modeId)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if modeId == "ffa" and count >= mode.minPlayers and ffaFillDeadline then
		return "filling"
	end

	return "waiting"
end

local function buildQueuePayload(modeId, forPlayer)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local fillRemaining = nil

	if modeId == "ffa" and ffaFillDeadline then
		fillRemaining = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = getPlayerNames(queue),
		count = count,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = getQueueStatus(modeId),
		fillRemaining = fillRemaining,
		isYou = forPlayer and playerMode[forPlayer] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearQueueForPlayer(player)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			return true
		end
		if ffaFillDeadline and os.clock() >= ffaFillDeadline then
			return true
		end
		return false
	end

	return count >= mode.maxPlayers
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local matchPlayers = {}

	local take = math.min(#queue, mode.maxPlayers)
	for _ = 1, take do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(matchPlayers, player)
			playerMode[player] = nil
			clearQueueForPlayer(player)
		end
	end

	if modeId == "ffa" then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end

	return matchPlayers
end

local function startMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	if not canStartMode(modeId) then
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	MatchStateService.setArenaBusy()

	for _, player in matchPlayers do
		HubService.enterArenaForMatch(player)
	end

	task.delay(MatchmakingConfig.START_DELAY, function()
		matchReadyBindable:Fire(matchPlayers, modeId)
	end)

	broadcastQueueUpdate(modeId)
end

local function tryStartAnyQueue()
	if MatchStateService.isArenaBusy() then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		if canStartMode(modeId) then
			startMatch(modeId)
			return
		end
	end
end

local function maybeStartFfaFillTimer()
	local mode = MatchModes.get("ffa")
	local queue = queues.ffa
	if #queue < mode.minPlayers then
		return
	end

	if ffaFillDeadline then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillDeadline = os.clock() + mode.fillTimeout

	task.delay(mode.fillTimeout, function()
		if token ~= ffaFillToken then
			return
		end
		broadcastQueueUpdate("ffa")
		tryStartAnyQueue()
	end)
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	removeFromAllQueues(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerMode[player] = modeId

	if modeId == "ffa" then
		maybeStartFfaFillTimer()
	end

	broadcastQueueUpdate(modeId)
	tryStartAnyQueue()
end

local function leaveQueue(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		clearQueueForPlayer(player)
		broadcastQueueUpdate(modeId)
	end
end

local function getQuickMatchModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start(remoteFolder, bindables)
	remotes = remoteFolder
	matchReadyBindable = bindables.MatchReady

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = getQuickMatchModeId()
		end
		joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		for _, modeId in { "training", "pvp", "ffa" } do
			broadcastQueueUpdate(modeId)
		end
		tryStartAnyQueue()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId, queue in queues do
				if #queue > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getQuickMatchModeId()
	return getQuickMatchModeId()
end

return MatchmakingService
