local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local ffaFillToken = 0
local handlers = {}

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function resolveModeId(modeId)
	if modeId == nil or modeId == "auto" then
		local count = #Players:GetPlayers()
		if handlers.getRecommendedMode then
			return handlers.getRecommendedMode(count)
		end
		return MatchmakingConfig.getRecommendedMode(count)
	end
	return modeId
end

local function queueIndex(modeId, player)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function removeFromQueue(player)
	local info = playerQueue[player]
	if not info then
		return
	end

	local index = queueIndex(info.modeId, player)
	if index then
		table.remove(queues[info.modeId], index)
	end
	playerQueue[player] = nil
end

local function setQueueStatus(modeId, status)
	for _, player in queues[modeId] do
		local info = playerQueue[player]
		if info then
			info.status = status
		end
	end
end

local function buildQueuePayload(player)
	local info = playerQueue[player]
	if not info then
		return nil
	end

	local mode = getMode(info.modeId)
	local queue = queues[info.modeId]
	return {
		modeId = info.modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = info.status,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player)
	local payload = buildQueuePayload(player)
	if payload then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdate()
	for player in playerQueue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function scheduleFfaFillTimer()
	if #queues.ffa == 0 then
		cancelFfaFillTimer()
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	local mode = MatchModes.ffa

	task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		if #queues.ffa >= mode.minPlayers then
			MatchmakingService.tryStartMatch("ffa")
		elseif #queues.ffa > 0 then
			scheduleFfaFillTimer()
		end
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		setQueueStatus(modeId, "pending")
		broadcastQueueUpdate()
		return
	end

	local matchPlayers = {}
	local takeCount = math.min(#queue, mode.maxPlayers)
	for index = 1, takeCount do
		table.insert(matchPlayers, queue[index])
	end

	for index = takeCount, 1, -1 do
		local player = queue[index]
		table.remove(queue, index)
		playerQueue[player] = nil
	end

	if modeId == "ffa" then
		cancelFfaFillTimer()
		if #queues.ffa > 0 then
			scheduleFfaFillTimer()
		end
	end

	broadcastQueueUpdate()

	for _, player in matchPlayers do
		if handlers.leaveHubForArena then
			handlers.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if playerQueue[player] then
		return
	end

	modeId = resolveModeId(modeId)
	if not isValidMode(modeId) then
		return
	end

	local info = {
		modeId = modeId,
		status = "waiting",
	}
	playerQueue[player] = info
	table.insert(queues[modeId], player)

	sendQueueUpdate(player)
	broadcastQueueUpdate()

	local mode = getMode(modeId)
	if #queues[modeId] >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif modeId == "ffa" and #queues[modeId] == 1 then
		scheduleFfaFillTimer()
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)

	if modeId == "ffa" and #queues.ffa == 0 then
		cancelFfaFillTimer()
	end

	Remotes.QueueUpdate:FireClient(player, nil)
	broadcastQueueUpdate()
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.configure(newHandlers)
	handlers = newHandlers or {}
end

function MatchmakingService.start()
	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onBusyChanged(function(isBusy)
		if isBusy then
			return
		end
		for modeId in queues do
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

return MatchmakingService
