local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local arenaBusy = false
local fillTokens = {}
local fillTimerRunning = {}

local function getValidPlayers(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	queues[modeId] = list
	return list
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queued = getValidPlayers(modeId)
	local position = 0
	for i, p in queued do
		if p == player then
			position = i
			break
		end
	end

	local status = "waiting"
	local statusMessage = string.format("%s — %d/%d in Warteschlange", mode.label, #queued, mode.maxPlayers)
	if arenaBusy then
		status = "pending"
		statusMessage = "Arena belegt — du bist als Nächstes dran"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queued,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusMessage = statusMessage,
	}
end

local function broadcastQueueUpdate(targetPlayer)
	local payload = buildQueuePayload(targetPlayer)
	Remotes.QueueUpdate:FireClient(targetPlayer, payload)
end

local function broadcastAllQueues()
	for modeId, _ in queues do
		for _, player in getValidPlayers(modeId) do
			broadcastQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillTimerRunning[modeId] = false
end

local function startFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or not mode.fillTimeout or fillTimerRunning[modeId] then
		return
	end

	fillTimerRunning[modeId] = true
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token or arenaBusy then
			return
		end
		fillTimerRunning[modeId] = false
		MatchmakingService.tryStartMatch(modeId, true)
	end)
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.leaveQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local nextQueue = {}
	for _, p in queues[modeId] do
		if p ~= player then
			table.insert(nextQueue, p)
		end
	end
	queues[modeId] = nextQueue

	local mode = MatchmakingConfig.getMode(modeId)
	if mode and #getValidPlayers(modeId) < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastAllQueues()
	if not silent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	MatchmakingService.leaveQueue(player, true)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(player)
	broadcastAllQueues()
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.tryStartMatch(modeId, forceStart)
	if arenaBusy then
		broadcastAllQueues()
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local queued = getValidPlayers(modeId)
	local count = #queued
	if count < mode.minPlayers then
		return
	end

	if mode.fillTimeout and count < mode.maxPlayers and not forceStart then
		startFillTimer(modeId)
		return
	end

	cancelFillTimer(modeId)

	local matchPlayers = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(matchPlayers, queued[i])
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	local remaining = {}
	for i = #matchPlayers + 1, #queued do
		table.insert(remaining, queued[i])
	end
	queues[modeId] = remaining

	arenaBusy = true
	broadcastAllQueues()

	Bindables.MatchReady:Fire({
		players = matchPlayers,
		mode = modeId,
	})
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	broadcastAllQueues()

	for modeId, _ in queues do
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.init()
	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
