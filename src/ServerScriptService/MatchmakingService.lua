--[[
	MatchmakingService — per-mode queues with fill timeout and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local started = false

for _, mode in MatchModes.all() do
	queues[mode.id] = {}
end

local function getQueuePosition(modeId, player)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function removeFromAllQueues(player)
	local previous = playerQueue[player]
	if not previous then
		return
	end

	local queue = queues[previous]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil
	fillTokens[previous] = (fillTokens[previous] or 0) + 1
end

local function buildUpdate(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = getQueuePosition(modeId, player) or #queue
	local message

	if status == "pending" then
		message = "Arena belegt — warte auf freien Slot..."
	elseif status == "starting" then
		message = "Match startet..."
	elseif #queue >= mode.minPlayers then
		message = "Spieler gefunden — starte bald..."
	else
		message = string.format("Warte auf Spieler (%d/%d)...", #queue, mode.minPlayers)
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		position = position,
		queueSize = #queue,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		message = message,
		inQueue = true,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildUpdate(queuedPlayer, modeId, status))
		end
	end
end

local function clearQueueUI(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function takePlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(matchPlayers, nextPlayer)
			playerQueue[nextPlayer] = nil
			clearQueueUI(nextPlayer)
		end
	end

	return matchPlayers
end

local function startMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers < mode.minPlayers then
		return
	end

	for _, player in matchPlayers do
		HubService.leaveHubForArena(player)
		Remotes.QueueUpdate:FireClient(player, buildUpdate(player, modeId, "starting"))
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
	broadcastQueue(modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end

		local queue = queues[modeId]
		if #queue >= mode.minPlayers and not MatchStateService.isArenaBusy() then
			startMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]

	if #queue == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if #queue >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers and mode.fillTimeout <= 0 then
		startMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers and mode.fillTimeout > 0 then
		scheduleFillTimeout(modeId)
	end

	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		return true
	end

	removeFromAllQueues(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromAllQueues(player)
	clearQueueUI(player)
	broadcastQueue(modeId)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onArenaFreed()
	for modeId in queues do
		if #queues[modeId] > 0 then
			evaluateQueue(modeId)
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId, queue in queues do
				if #queue > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if not MatchStateService.isArenaBusy() then
				MatchmakingService.onArenaFreed()
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
