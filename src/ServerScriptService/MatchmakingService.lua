local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchFlowState = require(script.Parent.MatchFlowState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables
local HubCallbacks

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingModes = {}

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function buildUpdatePayload(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	local count = getQueueCount(modeId)
	local status = "waiting"
	if MatchFlowState.isBusy() then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = status,
	}
end

local function sendUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			sendUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = nil
	sendUpdate(player)
	broadcastQueue(modeId)
end

local function pullPlayers(modeId, count)
	local queue = queues[modeId]
	local pulled = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(pulled, player)
		end
	end
	broadcastQueue(modeId)
	return pulled
end

local function markPlayersArena(players)
	if HubCallbacks and HubCallbacks.leaveHubForArena then
		for _, player in players do
			HubCallbacks.leaveHubForArena(player)
		end
	end
end

local function startMatch(modeId, players)
	if #players == 0 then
		return
	end

	fillTokens[modeId] = nil
	pendingModes[modeId] = false
	markPlayersArena(players)

	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = MatchmakingConfig.getMode(modeId).label,
			status = "starting",
		})
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

local function canStart(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout > 0 and fillTokens[modeId] then
		return false
	end
	if mode.fillTimeout == 0 and count >= mode.minPlayers then
		return true
	end
	return false
end

local function tryStartMatch(modeId)
	if MatchFlowState.isBusy() then
		pendingModes[modeId] = true
		broadcastQueue(modeId)
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local count = getQueueCount(modeId)

	if count < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 and count < mode.maxPlayers and not fillTokens[modeId] then
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
		local token = fillTokens[modeId]
		broadcastQueue(modeId)

		task.delay(mode.fillTimeout, function()
			if fillTokens[modeId] ~= token then
				return
			end
			if MatchFlowState.isBusy() then
				pendingModes[modeId] = true
				broadcastQueue(modeId)
				return
			end
			local readyCount = getQueueCount(modeId)
			if readyCount >= mode.minPlayers then
				local players = pullPlayers(modeId, math.min(readyCount, mode.maxPlayers))
				startMatch(modeId, players)
			end
			fillTokens[modeId] = nil
		end)
		return
	end

	if canStart(modeId) then
		local players = pullPlayers(modeId, mode.maxPlayers)
		startMatch(modeId, players)
	end
end

local function tryStartPending()
	for modeId in MatchmakingConfig.MODES do
		if pendingModes[modeId] and getQueueCount(modeId) > 0 then
			pendingModes[modeId] = false
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		sendUpdate(player)
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchFlowState.setBusy(false)
	task.defer(tryStartPending)
end

function MatchmakingService.init(hubContext, hubCallbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	HubCallbacks = hubCallbacks
	initQueues()

	if hubContext then
		if hubContext.portalPrompt then
			hubContext.portalPrompt.ActionText = "Warteschlange"
			hubContext.portalPrompt.ObjectText = "Nova Arena"
			hubContext.portalPrompt.Triggered:Connect(function(player)
				MatchmakingService.joinQueue(player, hubContext.getActiveModeId())
			end)
		end

		for _, pad in hubContext.modePads do
			if pad.prompt then
				pad.prompt.Triggered:Connect(function(player)
					MatchmakingService.joinQueue(player, pad.config.id)
				end)
			end
		end
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = hubContext and hubContext.getActiveModeId() or "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
