local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local ffaFillToken = 0
local remotes
local matchReadyEvent
local leaveHubForArena
local queueUpdateRemote

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player, entry)
	local modeId = entry.modeId
	local modeConfig = getModeConfig(modeId)
	local waiting = countQueue(modeId)
	local status = entry.status

	if GameMatchState.isArenaBusy() and status == "waiting" then
		status = "pending"
	end

	return {
		inQueue = true,
		mode = modeId,
		modeLabel = MatchModes.getLabel(modeId),
		status = status,
		playersWaiting = waiting,
		playersNeeded = modeConfig.minPlayers,
		maxPlayers = modeConfig.maxPlayers,
	}
end

local function broadcastQueue(player)
	local entry = playerEntry[player]
	if not entry then
		queueUpdateRemote:FireClient(player, { inQueue = false })
		return
	end
	queueUpdateRemote:FireClient(player, buildQueuePayload(player, entry))
end

local function broadcastModeQueue(modeId)
	for player, entry in playerEntry do
		if entry.modeId == modeId and player.Parent then
			broadcastQueue(player)
		end
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
	broadcastQueue(player)
	broadcastModeQueue(modeId)

	if modeId == "ffa" and #queues.ffa < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillToken += 1
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerEntry[player] = nil
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	GameMatchState.setArenaBusy(true)

	for _, player in playerList do
		if leaveHubForArena then
			leaveHubForArena(player)
		end
		queueUpdateRemote:FireClient(player, { inQueue = false, starting = true })
	end

	matchReadyEvent:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	if GameMatchState.isArenaBusy() then
		return false
	end

	local modeConfig = getModeConfig(modeId)
	local waiting = countQueue(modeId)
	if waiting < modeConfig.minPlayers then
		return false
	end

	local count = math.min(waiting, modeConfig.maxPlayers)
	local playerList = popPlayers(modeId, count)
	if #playerList < modeConfig.minPlayers then
		for _, player in playerList do
			table.insert(queues[modeId], player)
			playerEntry[player] = { modeId = modeId, status = "waiting" }
		end
		return false
	end

	startMatch(modeId, playerList)
	broadcastModeQueue(modeId)
	return true
end

local function scheduleFfaFill()
	local modeConfig = MatchmakingConfig.MODES.ffa
	if countQueue("ffa") < modeConfig.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(modeConfig.fillTimeout, function()
		if token ~= ffaFillToken then
			return
		end
		if GameMatchState.isArenaBusy() then
			return
		end
		if countQueue("ffa") < modeConfig.minPlayers then
			return
		end
		tryStartMode("ffa")
	end)
end

local function processQueues()
	for _, modeId in { "training", "pvp" } do
		local modeConfig = getModeConfig(modeId)
		while not GameMatchState.isArenaBusy() and countQueue(modeId) >= modeConfig.minPlayers do
			if not tryStartMode(modeId) then
				break
			end
		end
	end

	if not GameMatchState.isArenaBusy() and countQueue("ffa") >= MatchmakingConfig.MODES.ffa.maxPlayers then
		tryStartMode("ffa")
	end
end

local function onArenaFree()
	for _, entry in playerEntry do
		if entry.status == "pending" then
			entry.status = "waiting"
		end
	end

	for player in playerEntry do
		if player.Parent then
			broadcastQueue(player)
		end
	end

	processQueues()
	scheduleFfaFill()
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerEntry[player] then
		return false, "already_queued"
	end
	local modeConfig = getModeConfig(modeId)
	if countQueue(modeId) >= modeConfig.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = GameMatchState.isArenaBusy() ? "pending" : "waiting",
	}

	broadcastQueue(player)
	broadcastModeQueue(modeId)

	if modeId == "ffa" then
		if countQueue("ffa") >= modeConfig.minPlayers then
			scheduleFfaFill()
		end
		if countQueue("ffa") >= modeConfig.maxPlayers then
			tryStartMode("ffa")
		end
	else
		processQueues()
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId
end

function MatchmakingService.start(deps)
	remotes = deps.remotes
	matchReadyEvent = deps.matchReadyEvent
	leaveHubForArena = deps.leaveHubForArena
	queueUpdateRemote = remotes.QueueUpdate

	deps.arenaFreeEvent.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
