local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local ffaFillDeadline = nil
local arenaBusy = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueueList(queue, player)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function clearPlayerEntry(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	removeFromQueueList(queues[entry.modeId], player)
	playerEntry[player] = nil

	if entry.modeId == "ffa" and #queues.ffa < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillDeadline = nil
	end
end

local function getQueueStatus(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end

	return {
		modeId = modeId,
		label = config.label,
		queued = #queues[modeId],
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		fillTimeout = config.fillTimeout,
	}
end

local function buildPlayerUpdate(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local queueStatus = getQueueStatus(entry.modeId)
	local secondsLeft = nil
	if entry.modeId == "ffa" and ffaFillDeadline then
		secondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		status = entry.status,
		label = queueStatus.label,
		queued = queueStatus.queued,
		minPlayers = queueStatus.minPlayers,
		maxPlayers = queueStatus.maxPlayers,
		secondsLeft = secondsLeft,
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdates()
	for player, _ in playerEntry do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
		end
	end
end

local function setEntryStatus(modeId, status)
	for _, queuedPlayer in queues[modeId] do
		local entry = playerEntry[queuedPlayer]
		if entry then
			entry.status = status
		end
	end
end

local function pullPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(matchPlayers, nextPlayer)
			playerEntry[nextPlayer] = nil
		end
	end

	if modeId == "ffa" then
		ffaFillDeadline = nil
	end

	return matchPlayers
end

local function startMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	arenaBusy = true
	setEntryStatus(modeId, "starting")

	for _, player in matchPlayers do
		HubService.enterArenaForMatch(player)
	end

	broadcastQueueUpdates()
	Bindables.MatchReady:Fire({
		players = matchPlayers,
		mode = modeId,
	})
end

local function tryStartMode(modeId)
	if arenaBusy then
		setEntryStatus(modeId, "pending")
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= config.maxPlayers then
			startMatch(modeId, pullPlayers(modeId))
			return
		end

		if not ffaFillDeadline then
			ffaFillDeadline = os.clock() + (config.fillTimeout or 12)
			setEntryStatus(modeId, "waiting")
			broadcastQueueUpdates()
			return
		end

		if os.clock() < ffaFillDeadline then
			return
		end
	end

	startMatch(modeId, pullPlayers(modeId))
end

local function evaluateQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

local function joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if playerEntry[player] then
		return
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = arenaBusy and "pending" or "waiting",
	}

	Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
	tryStartMode(modeId)
end

local function leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	clearPlayerEntry(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates()
end

local function onMatchEnded()
	arenaBusy = false
	broadcastQueueUpdates()
	evaluateQueues()
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = "training"
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(onMatchEnded)

Players.PlayerRemoving:Connect(function(player)
	clearPlayerEntry(player)
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		if ffaFillDeadline and os.clock() >= ffaFillDeadline then
			tryStartMode("ffa")
		end
		broadcastQueueUpdates()
	end
end)

print("[MatchmakingService] Queue ready — Training / PvP / FFA")

return {
	joinQueue = joinQueue,
	leaveQueue = leaveQueue,
	isQueued = function(player)
		return playerEntry[player] ~= nil
	end,
}
