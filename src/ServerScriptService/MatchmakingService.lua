--[[
	MatchmakingService — per-mode queues with fill timeout and arena-pending state.
]]

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

local queues = {}
local playerQueue = {}
local fillTokens = {}
local starting = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getModeLabel(modeId)
	local mode = MatchModes.get(modeId)
	return mode and mode.label or modeId
end

local function buildStatus(modeId)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	if starting then
		return "starting"
	end
	return "waiting"
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = buildStatus(modeId),
		statusLabel = MatchStateService.isArenaBusy()
			and MatchmakingConfig.PENDING_LABEL
			or MatchmakingConfig.QUEUE_LABEL,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			local payload = buildQueuePayload(modeId, player)
			if payload then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil
	clearFillTimer(modeId)

	if not silent then
		broadcastQueueUpdate(modeId)
		tryStartMode(modeId)
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	return mode.fillTimeout <= 0
end

local function launchMatch(modeId)
	if starting or MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or #queue < mode.minPlayers then
		return
	end

	local playerList = {}
	for index = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(playerList, queue[index])
	end

	if #playerList == 0 then
		return
	end

	starting = true
	clearFillTimer(modeId)

	for _, player in playerList do
		removeFromQueue(player, true)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				modeLabel = mode.label,
				players = #playerList,
				minPlayers = mode.minPlayers,
				maxPlayers = mode.maxPlayers,
				position = 1,
				status = "starting",
				statusLabel = MatchmakingConfig.STARTING_LABEL,
			})
		end
	end

	MatchReady:Fire(playerList, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	clearFillTimer(modeId)
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end

		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers and not MatchStateService.isArenaBusy() and not starting then
			launchMatch(modeId)
		end
	end)
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() or starting then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or #queue < mode.minPlayers then
		return
	end

	if #queue >= mode.maxPlayers then
		launchMatch(modeId)
		return
	end

	if mode.fillTimeout <= 0 then
		launchMatch(modeId)
		return
	end

	if not fillTokens[modeId] or fillTokens[modeId] == 0 then
		scheduleFillTimeout(modeId)
	end
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		broadcastQueueUpdate(modeId)
		return
	end

	removeFromQueue(player, true)

	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)
	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	tryStartMode(modeId)
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	removeFromQueue(player, false)
end

local function onMatchReadyHandled()
	starting = false
end

local function onMatchEnded()
	starting = false
	for _, modeId in MatchModes.allIds() do
		broadcastQueueUpdate(modeId)
		tryStartMode(modeId)
	end
end

local function onArenaBusyChanged(busy)
	if busy then
		for _, modeId in MatchModes.allIds() do
			broadcastQueueUpdate(modeId)
		end
		return
	end

	onMatchEnded()
end

function MatchmakingService.init(hubApi)
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded

	MatchmakingService._hubApi = hubApi

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = hubApi.getActiveModeId()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	MatchReady.Event:Connect(onMatchReadyHandled)
	MatchEnded.Event:Connect(onMatchEnded)
	MatchStateService.onArenaBusyChanged(onArenaBusyChanged)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
