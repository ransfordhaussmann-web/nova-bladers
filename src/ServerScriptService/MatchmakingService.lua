local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local ArenaFree = Bindables.ArenaFree

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local ffaFillToken = 0

local function getModeConfig(modeId)
	return MatchModes.get(modeId)
end

local function findPlayerQueue(player)
	for modeId, queue in queues do
		for index, queuedPlayer in queue do
			if queuedPlayer == player then
				return modeId, index
			end
		end
	end
	return nil
end

local function buildQueueMessage(modeId, queueSize, arenaBusy)
	local mode = getModeConfig(modeId)
	if arenaBusy then
		return "Arena belegt — du startest als Nächstes"
	end
	if modeId == "training" then
		return "Suche Trainings-Arena..."
	end
	if modeId == "pvp" then
		if queueSize < mode.minPlayers then
			return string.format("Warte auf Gegner (%d/%d)", queueSize, mode.minPlayers)
		end
		return "Gegner gefunden!"
	end
	if queueSize < mode.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)", queueSize, mode.minPlayers)
	end
	return string.format("Lobby füllt sich (%d/%d)", queueSize, mode.maxPlayers)
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	local arenaBusy = GameMatchState.isBusy()

	for index, player in queue do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = mode.label,
			position = index,
			queueSize = #queue,
			needed = mode.minPlayers,
			maxPlayers = mode.maxPlayers,
			status = arenaBusy and "pending" or "waiting",
			message = buildQueueMessage(modeId, #queue, arenaBusy),
		})
	end
end

local function clearPlayerQueueUI(player)
	sendQueueUpdate(player, { inQueue = false })
end

local function removeFromQueue(player)
	local modeId = findPlayerQueue(player)
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			clearPlayerQueueUI(player)
			broadcastQueue(modeId)
			return modeId
		end
	end
	return nil
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		table.insert(picked, table.remove(queue, 1))
	end
	return picked
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function startFfaFillTimer()
	cancelFfaFillTimer()
	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		if GameMatchState.isBusy() then
			return
		end
		if #queues.ffa >= MatchmakingConfig.MODES.ffa.minPlayers then
			MatchmakingService.tryStartMode("ffa")
		end
	end)
end

function MatchmakingService.tryStartMode(modeId)
	if GameMatchState.isBusy() then
		return false
	end

	local mode = getModeConfig(modeId)
	if not mode then
		return false
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, playerCount)
	if #players == 0 then
		return false
	end

	for _, player in players do
		clearPlayerQueueUI(player)
		HubService.leaveForMatch(player)
	end

	if modeId == "ffa" then
		cancelFfaFillTimer()
	end

	GameMatchState.setBusy(true)
	MatchReady:Fire({
		modeId = modeId,
		players = players,
	})

	broadcastQueue(modeId)
	return true
end

local function evaluateMode(modeId)
	local mode = getModeConfig(modeId)
	local queue = queues[modeId]
	if not mode or #queue == 0 then
		return
	end

	if GameMatchState.isBusy() then
		broadcastQueue(modeId)
		return
	end

	if modeId == "training" or modeId == "pvp" then
		if #queue >= mode.minPlayers then
			MatchmakingService.tryStartMode(modeId)
		end
		return
	end

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMode("ffa")
		return
	end

	if #queue >= mode.minPlayers then
		startFfaFillTimer()
	end
end

local function evaluateAllQueues()
	for modeId in MatchmakingConfig.MODES do
		evaluateMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end
	if findPlayerQueue(player) then
		return false
	end

	table.insert(queues[modeId], player)
	broadcastQueue(modeId)
	evaluateMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId == "ffa" and #queues.ffa < MatchmakingConfig.MODES.ffa.minPlayers then
		cancelFfaFillTimer()
	end
	return modeId ~= nil
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.MODES.ffa.minPlayers then
		return "ffa"
	elseif count >= MatchmakingConfig.MODES.pvp.minPlayers then
		return "pvp"
	end
	return "training"
end

local function onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

local function onArenaFree()
	GameMatchState.setBusy(false)
	evaluateAllQueues()
end

function MatchmakingService.start()
Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if modeId == nil or modeId == "" then
		modeId = MatchmakingService.getRecommendedModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(onPlayerRemoving)
	ArenaFree.Event:Connect(onArenaFree)
end

return MatchmakingService
