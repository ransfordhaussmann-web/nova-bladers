local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueueList(modeId, player)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function buildUpdatePayload(modeId, player)
	local mode = getModeConfig(modeId)
	local count = queueCount(modeId)
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif modeId == "training" and count >= mode.minPlayers then
		status = "starting"
	elseif count >= mode.maxPlayers then
		status = "starting"
	elseif count >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	local message
	if status == "pending" then
		message = "Arena belegt — du bist in der Warteschlange"
	elseif status == "starting" then
		message = "Match startet..."
	elseif status == "filling" then
		message = string.format("Warte auf weitere Spieler (%d/%d)", count, mode.maxPlayers)
	elseif modeId == "pvp" then
		message = string.format("Warte auf Gegner (%d/%d)", count, mode.maxPlayers)
	elseif modeId == "ffa" then
		message = string.format("Warte auf Spieler (%d/%d)", count, mode.minPlayers)
	else
		message = "Queue beigetreten"
	end

	return {
		mode = modeId,
		modeLabel = mode.label,
		status = status,
		queueSize = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		message = message,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueueList(modeId, player)
	playerQueue[player] = nil

	if queueCount(modeId) < getModeConfig(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function popPlayers(modeId, amount)
	local picked = {}
	local queue = queues[modeId]
	for _ = 1, math.min(amount, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	cancelFillTimer(modeId)
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		HubService.enterArena(player)
		Remotes.QueueUpdate:FireClient(player, {
			mode = modeId,
			status = "starting",
			message = "Match startet...",
			inQueue = false,
		})
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartQueue(modeId)
	local mode = getModeConfig(modeId)
	local count = queueCount(modeId)

	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if mode.minPlayers == mode.maxPlayers and count >= mode.minPlayers then
		startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if count >= mode.maxPlayers then
		startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if fillTimers[modeId] then
		return
	end

	if mode.fillTimeout <= 0 then
		startMatch(modeId, popPlayers(modeId, count))
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		if MatchStateService.isArenaBusy() then
			broadcastQueue(modeId)
			return
		end

		local readyCount = queueCount(modeId)
		if readyCount >= mode.minPlayers then
			startMatch(modeId, popPlayers(modeId, math.min(readyCount, mode.maxPlayers)))
		else
			broadcastQueue(modeId)
		end
	end)

	broadcastQueue(modeId)
end

function MatchmakingService.evaluateAllQueues()
	for modeId in MatchmakingConfig.MODES do
		tryStartQueue(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return
	end

	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		return
	end

	clearPlayerFromQueues(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	HubService.enterQueue(player, modeId)

	broadcastQueue(modeId)
	tryStartQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	clearPlayerFromQueues(player)
	HubService.leaveQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.joinRecommendedQueue(player)
	local bestModeId = "training"
	local bestCount = -1

	for _, modeId in MatchmakingConfig.PORTAL_MODE_ORDER do
		local count = queueCount(modeId)
		if count > bestCount then
			bestCount = count
			bestModeId = modeId
		end
	end

	MatchmakingService.joinQueue(player, bestModeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(MatchmakingService.evaluateAllQueues)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.init(remotes, bindables)
	Remotes = remotes
	Bindables = bindables

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == nil or modeId == "recommended" then
			MatchmakingService.joinRecommendedQueue(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(MatchmakingService.onMatchEnded)

	Players.PlayerRemoving:Connect(MatchmakingService.onPlayerRemoving)
end

return MatchmakingService
