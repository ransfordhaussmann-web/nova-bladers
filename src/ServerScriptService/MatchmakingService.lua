local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local callbacks = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillDeadline = nil
local ffaTimerToken = 0

local function getQueueList(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueueList(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if entry.modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
		ffaTimerToken += 1
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes[modeId]
	local queue = getQueueList(modeId)
	local inQueue = playerQueue[player] ~= nil
	local arenaBusy = MatchStateService.isArenaBusy()

	local status = "waiting"
	local message = "Warte auf Mitspieler..."

	if inQueue then
		if arenaBusy then
			status = "pending"
			message = "Arena belegt — du bist als Nächster dran"
		elseif #queue >= mode.maxPlayers then
			status = "starting"
			message = "Match startet gleich..."
		elseif modeId == "ffa" and #queue >= mode.minPlayers and ffaFillDeadline then
			status = "waiting"
			local left = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
			message = string.format("FFA startet in %ds (%d/%d)", left, #queue, mode.maxPlayers)
		elseif #queue >= mode.minPlayers then
			status = "starting"
			message = "Match startet gleich..."
		else
			message = string.format("Warte auf Spieler (%d/%d)", #queue, mode.minPlayers)
		end
	end

	local fillTimeLeft = nil
	if modeId == "ffa" and ffaFillDeadline and #queue >= mode.minPlayers then
		fillTimeLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		inQueue = inQueue,
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		message = message,
		fillTimeLeft = fillTimeLeft,
		arenaBusy = arenaBusy,
	}
end

local function sendQueueUpdate(player)
	local entry = playerQueue[player]
	if not entry then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, entry.modeId))
end

local function broadcastQueueUpdates(modeId)
	for player, entry in playerQueue do
		if entry.modeId == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function broadcastAllQueueUpdates()
	for player in playerQueue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function takePlayers(modeId, count)
	local queue = getQueueList(modeId)
	local taken = {}
	for i = 1, math.min(count, #queue) do
		table.insert(taken, queue[1])
		playerQueue[queue[1]] = nil
		table.remove(queue, 1)
	end
	return taken
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	ffaFillDeadline = nil
	ffaTimerToken += 1

	for _, player in playerList do
		if callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
	end

	broadcastAllQueueUpdates()

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	local mode = MatchModes[modeId]
	local queue = getQueueList(modeId)

	if modeId == "training" then
		if #queue >= 1 then
			launchMatch(modeId, takePlayers(modeId, 1))
		end
	elseif modeId == "pvp" then
		if #queue >= 2 then
			launchMatch(modeId, takePlayers(modeId, 2))
		end
	elseif modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		elseif #queue >= mode.minPlayers and ffaFillDeadline and os.clock() >= ffaFillDeadline then
			launchMatch(modeId, takePlayers(modeId, #queue))
		end
	end
end

local function scheduleFfaFillTimer()
	local mode = MatchModes.ffa
	local queue = getQueueList("ffa")

	if #queue < mode.minPlayers then
		ffaFillDeadline = nil
		return
	end

	if ffaFillDeadline then
		return
	end

	ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	ffaTimerToken += 1
	local token = ffaTimerToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaTimerToken then
			return
		end
		tryStartMatch("ffa")
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return
	end
	if playerQueue[player] then
		removeFromQueue(player)
	end

	table.insert(getQueueList(modeId), player)
	playerQueue[player] = { modeId = modeId, joinedAt = os.clock() }

	if modeId == "ffa" then
		scheduleFfaFillTimer()
	end

	sendQueueUpdate(player)
	tryStartMatch(modeId)
end

function MatchmakingService.joinRecommendedQueue(player)
	if callbacks.getRecommendedMode then
		MatchmakingService.joinQueue(player, callbacks.getRecommendedMode())
	else
		MatchmakingService.joinQueue(player, "training")
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	broadcastAllQueueUpdates()

	for modeId in MatchModes do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.init(hubCallbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	callbacks = hubCallbacks or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == nil or modeId == "" then
			MatchmakingService.joinRecommendedQueue(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for player in playerQueue do
				if player.Parent then
					sendQueueUpdate(player)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
