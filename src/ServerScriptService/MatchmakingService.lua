--[[
	MatchmakingService — per-mode queues with FFA fill timeout and arena-busy pending state.
]]

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

local playerMode = {}
local fillReadyAt = {}
local fillTokens = {}
local arenaBusy = false
local phaseHandler = nil
local recommendedModeHandler = nil

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function indexOfPlayer(modeId, player)
	for i, queued in queues[modeId] do
		if queued == player then
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

	local index = indexOfPlayer(modeId, player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerMode[player] = nil

	if modeId == "ffa" and queueCount("ffa") < getMode("ffa").minPlayers then
		fillReadyAt.ffa = nil
		fillTokens.ffa = (fillTokens.ffa or 0) + 1
	end
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getMode(modeId)
	local count = queueCount(modeId)
	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif modeId == "ffa" and count >= mode.minPlayers and fillReadyAt.ffa and os.clock() < fillReadyAt.ffa then
		status = "filling"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	local fillSecondsLeft = nil
	if modeId == "ffa" and fillReadyAt.ffa then
		fillSecondsLeft = math.max(0, math.ceil(fillReadyAt.ffa - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = indexOfPlayer(modeId, player) or count,
		queued = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates()
	for player in playerMode do
		sendQueueUpdate(player)
	end
end

local function setPlayerPhase(player, phase)
	if phaseHandler then
		phaseHandler(player, phase)
	end
end

local function startFillTimer(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 then
		return
	end
	if fillReadyAt[modeId] then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillReadyAt[modeId] = os.clock() + mode.fillTimeout
	broadcastQueueUpdates()

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillReadyAt[modeId] = os.clock()
		broadcastQueueUpdates()
		MatchmakingService.tryStartMatches()
	end)
end

local function canStartMode(modeId)
	local mode = getMode(modeId)
	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			return true
		end
		return fillReadyAt.ffa ~= nil and os.clock() >= fillReadyAt.ffa
	end
	return true
end

local function popPlayers(modeId)
	local mode = getMode(modeId)
	local take = math.min(queueCount(modeId), mode.maxPlayers)
	local matched = {}
	for _ = 1, take do
		local player = table.remove(queues[modeId], 1)
		if player and player.Parent then
			table.insert(matched, player)
			playerMode[player] = nil
		end
	end

	if modeId == "ffa" then
		fillReadyAt.ffa = nil
		fillTokens.ffa = (fillTokens.ffa or 0) + 1
		if queueCount("ffa") >= mode.minPlayers then
			startFillTimer("ffa")
		end
	end

	return matched
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	broadcastQueueUpdates()
	if not busy then
		MatchmakingService.tryStartMatches()
	end
end

function MatchmakingService.tryStartMatches()
	if arenaBusy then
		return
	end

	for _, modeId in MatchmakingConfig.PRIORITY do
		if canStartMode(modeId) then
			local players = popPlayers(modeId)
			if #players > 0 then
				arenaBusy = true
				broadcastQueueUpdates()

				for _, player in players do
					setPlayerPhase(player, "arena")
					Remotes.HubState:FireClient(player, {
						phase = "arena",
						modeLabel = getMode(modeId).label,
					})
					sendQueueUpdate(player)
				end

				Bindables.MatchReady:Fire(players, modeId)
				return
			end
		end
	end
end

function MatchmakingService.join(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false
	end
	if playerMode[player] then
		MatchmakingService.leave(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	setPlayerPhase(player, "queue")

	local mode = getMode(modeId)
	if modeId == "ffa" and queueCount("ffa") == mode.minPlayers then
		startFillTimer("ffa")
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates()
	MatchmakingService.tryStartMatches()
	return true
end

function MatchmakingService.leave(player)
	if not playerMode[player] then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(player)
	setPlayerPhase(player, "hub")
	Remotes.HubState:FireClient(player, { phase = "hub" })
	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.isInQueue(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.init(options)
	phaseHandler = options.setPhase
	recommendedModeHandler = options.getRecommendedMode

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" and recommendedModeHandler then
			modeId = recommendedModeHandler()
		end
		MatchmakingService.join(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leave(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.setArenaBusy(false)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leave(player)
	end)
end

return MatchmakingService
