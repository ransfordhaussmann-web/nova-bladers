local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady
local MatchEnded

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local ffaFillEndsAt = nil
local hubCallbacks = {}

local function removeFromQueueList(player, modeId)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function clearPlayerQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end
	playerQueue[player] = nil
	removeFromQueueList(player, modeId)
	if modeId == "ffa" then
		ffaFillToken += 1
		ffaFillEndsAt = nil
	end
	return modeId
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	local fillSeconds = nil
	if modeId == "ffa" and ffaFillEndsAt and #queue >= mode.minPlayers then
		fillSeconds = math.max(0, math.ceil(ffaFillEndsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSeconds = fillSeconds,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchModes.allOrdered() do
		broadcastQueueUpdate(modeId)
	end
end

local function popMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local matchPlayers = {}
	local takeCount = math.min(#queue, mode.maxPlayers)

	for _ = 1, takeCount do
		local player = table.remove(queue, 1)
		if player then
			playerQueue[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	if modeId == "ffa" then
		ffaFillToken += 1
		ffaFillEndsAt = nil
	end

	return matchPlayers
end

local function launchMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	broadcastAllQueues()

	for _, player in matchPlayers do
		if hubCallbacks.leaveHubForArena then
			hubCallbacks.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(matchPlayers, modeId)
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" and #queue < mode.maxPlayers then
		return
	end

	local matchPlayers = popMatchPlayers(modeId)
	launchMatch(modeId, matchPlayers)
end

local function scheduleFfaFill()
	local mode = MatchModes.get("ffa")
	if #queues.ffa < mode.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillEndsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	broadcastQueueUpdate("ffa")

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		if MatchStateService.isArenaBusy() then
			return
		end
		if #queues.ffa < mode.minPlayers then
			return
		end

		local matchPlayers = popMatchPlayers("ffa")
		launchMatch("ffa", matchPlayers)
	end)
end

local function onFfaQueueChanged()
	local mode = MatchModes.get("ffa")
	local count = #queues.ffa

	if count >= mode.maxPlayers then
		tryStartMatch("ffa")
		return
	end

	if count == mode.minPlayers then
		scheduleFfaFill()
	end
end

local function tryStartAnyQueue()
	for _, modeId in MatchModes.allOrdered() do
		local mode = MatchModes.get(modeId)
		if #queues[modeId] >= mode.minPlayers then
			if modeId == "ffa" then
				if #queues.ffa >= mode.maxPlayers then
					tryStartMatch("ffa")
				elseif not ffaFillEndsAt then
					scheduleFfaFill()
				end
			else
				tryStartMatch(modeId)
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if playerQueue[player] then
		return false
	end
	if hubCallbacks.getPhase and hubCallbacks.getPhase(player) ~= "hub" then
		return false
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	if modeId == "ffa" then
		onFfaQueueChanged()
	elseif #queues[modeId] >= mode.maxPlayers then
		tryStartMatch(modeId)
	end

	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = clearPlayerQueue(player)
	if modeId then
		broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.getPlayerQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(callbacks)
	hubCallbacks = callbacks or {}

	local _, bindables = RemotesSetup.ensure()
	Remotes = ReplicatedStorage.NovaBladers.Remotes
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)
		task.defer(tryStartAnyQueue)
		broadcastAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for _, modeId in MatchModes.allOrdered() do
				if #queues[modeId] > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
