local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchFlowState = require(ReplicatedStorage.NovaBladers.MatchFlowState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

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

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and #queue < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local count = #queue
	local pending = MatchFlowState.isArenaBusy()

	local status = "searching"
	if pending then
		status = "pending"
	elseif count >= mode.minPlayers and mode.fillTimeout > 0 and ffaFillDeadline then
		status = "filling"
	end

	local payload = {
		inQueue = true,
		mode = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = count,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = pending,
	}

	if modeId == "ffa" and ffaFillDeadline then
		payload.fillSecondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return payload
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
end

local function popMatchPlayers(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	if count < mode.minPlayers then
		return nil
	end

	local matchPlayers = {}
	for i = 1, count do
		table.insert(matchPlayers, queue[1])
		playerMode[queue[1]] = nil
		table.remove(queue, 1)
	end

	if modeId == "ffa" then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end

	return matchPlayers
end

local function notifyLeftQueue(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function startMatch(modeId, matchPlayers)
	MatchFlowState.setArenaBusy(true)

	for _, queuedPlayer in matchPlayers do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, { inQueue = false, matchStarting = true })
		end
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})

	broadcastAllQueues()
end

local function tryStartMatch(modeId)
	if MatchFlowState.isArenaBusy() then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 then
		if not ffaFillDeadline then
			ffaFillDeadline = os.clock() + mode.fillTimeout
			ffaFillToken += 1
			local token = ffaFillToken
			broadcastQueue(modeId)

			task.delay(mode.fillTimeout, function()
				if token ~= ffaFillToken or MatchFlowState.isArenaBusy() then
					return
				end
				local players = popMatchPlayers(modeId)
				if players then
					startMatch(modeId, players)
				end
			end)
		end
		return
	end

	local players = popMatchPlayers(modeId)
	if players then
		startMatch(modeId, players)
	end
end

local function tryStartAllQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerMode[player] then
		removeFromQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		notifyLeftQueue(player)
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)
	notifyLeftQueue(player)
	broadcastQueue(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchFlowState.setArenaBusy(false)
	task.defer(tryStartAllQueues)
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerMode[player]
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

print("[MatchmakingService] Queue system ready")

return MatchmakingService
