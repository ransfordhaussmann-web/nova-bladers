local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local queues = {}
local playerMode = {}
local fillTasks = {}
local handlers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function cancelFillTask(modeId)
	local taskToken = fillTasks[modeId]
	if taskToken then
		fillTasks[modeId] = nil
	end
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local alive = {}
	for _, player in queue do
		if player.Parent and playerMode[player] == modeId then
			table.insert(alive, player)
		end
	end
	queues[modeId] = alive
	return alive
end

local function buildStatus(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = pruneQueue(modeId)
	local queueSize = #queue
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local message
	if status == "pending" then
		message = "Arena belegt — du bist als Nächstes dran"
	elseif mode.instant then
		message = string.format("Warte auf Spieler (%d/%d)", queueSize, mode.minPlayers)
	else
		message = string.format("Warte auf Spieler (%d/%d–%d)", queueSize, mode.minPlayers, mode.maxPlayers)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = queueSize,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status,
		message = message,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId, status)
	local queue = pruneQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player, buildStatus(player, modeId, status))
	end
end

local function clearPlayerQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		sendQueueUpdate(player, { inQueue = false })
		return
	end

	playerMode[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if #queue < MatchModes.get(modeId).minPlayers then
		cancelFillTask(modeId)
	end

	sendQueueUpdate(player, { inQueue = false })
	broadcastQueue(modeId, "waiting")
end

local function popPlayers(modeId, count)
	local queue = pruneQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			sendQueueUpdate(player, { inQueue = false, status = "starting" })
			table.insert(picked, player)
		end
	end
	cancelFillTask(modeId)
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId, "pending")
		return
	end

	MatchStateService.setBusy(true)
	MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = pruneQueue(modeId)
	if #queue == 0 then
		cancelFillTask(modeId)
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId, "pending")
		return
	end

	if mode.instant then
		if #queue >= mode.minPlayers then
			startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		else
			broadcastQueue(modeId, "waiting")
		end
		return
	end

	if #queue >= mode.maxPlayers then
		startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if #queue >= mode.minPlayers then
		if not fillTasks[modeId] then
			local token = {}
			fillTasks[modeId] = token
			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if fillTasks[modeId] ~= token then
					return
				end
				fillTasks[modeId] = nil
				local current = pruneQueue(modeId)
				if #current >= mode.minPlayers and not MatchStateService.isBusy() then
					startMatch(modeId, popPlayers(modeId, #current))
				else
					tryStartMode(modeId)
				end
			end)
		end
		broadcastQueue(modeId, "waiting")
	else
		cancelFillTask(modeId)
		broadcastQueue(modeId, "waiting")
	end
end

local function tryStartAllQueues()
	for modeId in MatchModes.all() do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	if MatchStateService.isBusy() and playerMode[player] == nil then
		-- Allow joining while arena is busy; players wait with pending status.
	end

	if playerMode[player] == modeId then
		sendQueueUpdate(player, buildStatus(player, modeId, MatchStateService.isBusy() and "pending" or "waiting"))
		return true
	end

	MatchmakingService.leaveQueue(player)

	playerMode[player] = modeId
	table.insert(getQueue(modeId), player)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	clearPlayerQueue(player)
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setBusy(false)
	tryStartAllQueues()
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

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId or MatchmakingService.getRecommendedModeId())
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if handlers.onMatchReady then
		MatchReady.Event:Connect(handlers.onMatchReady)
	end
end

return MatchmakingService
