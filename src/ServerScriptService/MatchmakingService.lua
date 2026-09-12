local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerMode = {}
local ffaFillToken = 0
local ffaFillActive = false
local started = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function resolveModeId(modeId)
	if typeof(modeId) == "string" and isValidMode(modeId) then
		return modeId
	end
	return MatchmakingConfig.resolveDefaultMode(#Players:GetPlayers())
end

local function queueIndex(modeId, player)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	local index = queueIndex(modeId, player)
	if index then
		table.remove(queue, index)
	end
	playerMode[player] = nil

	if modeId == "ffa" and #queue < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillToken += 1
		ffaFillActive = false
	end
end

local function buildQueuePayload(player, modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #queue
	local needed = math.max(0, config.minPlayers - count)
	local status = "waiting"

	if not GameMatchState.canStartMatch() then
		status = "pending"
	elseif modeId == "ffa" and count >= config.minPlayers and ffaFillActive then
		status = "waiting"
	elseif count >= config.minPlayers then
		status = "ready"
	end

	local message
	if status == "pending" then
		message = "Arena belegt — du bist in der Warteschlange"
	elseif modeId == "ffa" and count >= config.minPlayers and ffaFillActive then
		message = string.format("FFA startet bald (%d/%d)", count, config.maxPlayers)
	elseif needed > 0 then
		message = string.format("Warte auf %d Spieler…", needed)
	else
		message = "Match startet gleich…"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		playersInQueue = count,
		playersNeeded = needed,
		maxPlayers = config.maxPlayers,
		status = status,
		message = message,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
		return
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	end
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		sendQueueUpdate(player)
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function popPlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local matchPlayers = {}

	for i = 1, count do
		local player = queue[1]
		table.remove(queue, 1)
		playerMode[player] = nil
		table.insert(matchPlayers, player)
	end

	if modeId == "ffa" then
		ffaFillToken += 1
		ffaFillActive = false
	end

	return matchPlayers
end

local function launchMatch(modeId)
	if not GameMatchState.canStartMatch() then
		broadcastQueueUpdate(modeId)
		return false
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return false
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers < config.minPlayers then
		return false
	end

	GameMatchState.setBusy(true)

	for _, player in matchPlayers do
		HubService.enterArenaPhase(player)
		sendQueueUpdate(player)
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
	broadcastAllQueues()
	return true
end

local function scheduleFfaFill()
	local config = MatchmakingConfig.MODES.ffa
	local queue = queues.ffa
	if #queue < config.minPlayers or ffaFillActive then
		return
	end

	ffaFillActive = true
	ffaFillToken += 1
	local token = ffaFillToken

	broadcastQueueUpdate("ffa")

	task.delay(config.fillTimeout, function()
		if token ~= ffaFillToken or not ffaFillActive then
			return
		end
		ffaFillActive = false
		launchMatch("ffa")
	end)
end

local function tryStartMode(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= config.maxPlayers then
			ffaFillToken += 1
			ffaFillActive = false
			launchMatch("ffa")
			return
		end
		scheduleFfaFill()
		return
	end

	launchMatch(modeId)
end

local function tryStartAllQueues()
	for _, modeId in { "training", "pvp", "ffa" } do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end

	modeId = resolveModeId(modeId)
	if playerMode[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	MatchmakingService.leaveQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	sendQueueUpdate(player)
	if modeId then
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.getQueueMode(player)
	return playerMode[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	GameMatchState.onIdle(function()
		broadcastAllQueues()
		tryStartAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
