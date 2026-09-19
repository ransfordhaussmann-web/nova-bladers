local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

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
local pendingModes = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromList(list, player)
	for i = #list, 1, -1 do
		if list[i] == player then
			table.remove(list, i)
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local inQueue = playerQueue[player] == modeId

	return {
		inQueue = inQueue,
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = pendingModes[modeId] and "pending" or "waiting",
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function sendQueueCleared(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	removeFromList(getQueue(modeId), player)
	sendQueueCleared(player)
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if mode and #getQueue(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
		pendingModes[modeId] = nil
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	local limit = math.min(count, #queue)

	for i = 1, limit do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(taken, player)
	end

	return taken
end

local function launchMatch(modeId, playerList)
	clearFillTimer(modeId)
	pendingModes[modeId] = nil
	MatchStateService.setBusy(true)

	for _, player in playerList do
		if player.Parent then
			HubService.leaveHubForArena(player)
			sendQueueCleared(player)
		end
	end

	broadcastQueue(modeId)
	Bindables.MatchReady:Fire({
		players = playerList,
		mode = modeId,
	})
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isBusy() then
		pendingModes[modeId] = true
		broadcastQueue(modeId)
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			launchMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
			return
		end

		if not fillTimers[modeId] then
			local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
			fillTimers[modeId] = task.delay(timeout, function()
				fillTimers[modeId] = nil
				if #getQueue(modeId) >= mode.minPlayers and not MatchStateService.isBusy() then
					launchMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
				elseif #getQueue(modeId) >= mode.minPlayers then
					pendingModes[modeId] = true
					broadcastQueue(modeId)
				end
			end)
		end
		return
	end

	launchMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
end

local function tryStartPending()
	for modeId in pairs(pendingModes) do
		if not MatchStateService.isBusy() and #getQueue(modeId) >= MatchModes.get(modeId).minPlayers then
			tryStartMode(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end

	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		return
	end

	removePlayerFromQueue(player)

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	removePlayerFromQueue(player)
end

function MatchmakingService.joinAutoQueue(player)
	local count = #Players:GetPlayers()
	local modeId = MatchmakingConfig.resolveAutoMode(count)
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	tryStartPending()
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" and modeId ~= "" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinAutoQueue(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
