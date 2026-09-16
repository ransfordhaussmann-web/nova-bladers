local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local ffaFillDeadline = nil
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
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

local function queueCount(modeId)
	return #(queues[modeId] or {})
end

local function isPlayerQueued(player)
	return playerMode[player] ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local list = queues[modeId]
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, i)
			break
		end
	end
	playerMode[player] = nil

	if modeId == "ffa" and queueCount("ffa") < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local count = queueCount(modeId)
	local arenaBusy = MatchStateService.isArenaBusy()
	local status = "waiting"

	if arenaBusy then
		status = "pending"
	elseif modeId == "training" and count >= mode.minPlayers then
		status = "ready"
	elseif modeId == "pvp" and count >= mode.minPlayers then
		status = "ready"
	elseif modeId == "ffa" then
		if count >= mode.maxPlayers then
			status = "ready"
		elseif ffaFillDeadline and count >= mode.minPlayers then
			status = "starting"
		end
	end

	local waitSeconds = nil
	if modeId == "ffa" and ffaFillDeadline and count >= mode.minPlayers then
		waitSeconds = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		requiredPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		waitSeconds = waitSeconds,
		arenaBusy = arenaBusy,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastQueueUpdates(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			return true
		end
		return ffaFillDeadline ~= nil and os.clock() >= ffaFillDeadline
	end
	return count >= mode.minPlayers
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	local take = math.min(#list, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, take do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(matchPlayers, player)
		end
	end

	if modeId == "ffa" then
		ffaFillDeadline = nil
	end

	return matchPlayers
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end
	if not canStartMode(modeId) then
		return false
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers < MatchModes.get(modeId).minPlayers then
		for _, player in matchPlayers do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		return false
	end

	MatchStateService.setArenaBusy(true)
	for _, player in matchPlayers do
		HubService.leaveForMatch(player)
	end
	Bindables.MatchReady:Fire(matchPlayers, modeId)
	return true
end

local function processQueues()
	if MatchStateService.isArenaBusy() then
		for _, mode in MatchModes.all() do
			broadcastQueueUpdates(mode.id)
		end
		return
	end

	for _, mode in MatchModes.all() do
		if canStartMode(mode.id) then
			if tryStartMatch(mode.id) then
				return
			end
		end
	end

	for _, mode in MatchModes.all() do
		broadcastQueueUpdates(mode.id)
	end
end

local function maybeStartFfaTimer()
	local mode = MatchModes.ffa
	if queueCount("ffa") >= mode.minPlayers and not ffaFillDeadline then
		ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		modeId = getRecommendedModeId()
	end

	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	if isPlayerQueued(player) then
		if playerMode[player] == modeId then
			sendQueueUpdate(player)
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if modeId == "ffa" then
		maybeStartFfaTimer()
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerQueued(player) then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	if modeId then
		broadcastQueueUpdates(modeId)
	end
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.isQueued(player)
	return isPlayerQueued(player)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		processQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			if MatchStateService.isArenaBusy() then
				continue
			end
			if ffaFillDeadline and os.clock() >= ffaFillDeadline then
				processQueues()
			else
				for modeId in queues do
					if queueCount(modeId) > 0 then
						broadcastQueueUpdates(modeId)
					end
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
