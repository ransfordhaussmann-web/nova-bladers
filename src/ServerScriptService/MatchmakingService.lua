local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable
local onQueueChange

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local pendingMatch = nil

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

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local pending = pendingMatch ~= nil and pendingMatch.modeId == modeId

	local status = "waiting"
	if pending then
		status = "pending"
	elseif mode.maxPlayers > 1 and count >= mode.maxPlayers then
		status = "full"
	elseif mode.minPlayers == 1 and count >= 1 then
		status = "ready"
	elseif count >= mode.minPlayers then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = playerMode[player] == modeId,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
	if onQueueChange then
		onQueueChange(modeId, #queue)
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		table.insert(picked, table.remove(queue, 1))
	end
	for _, pickedPlayer in picked do
		playerMode[pickedPlayer] = nil
	end
	return picked
end

local function launchMatch(modeId, playerList)
	pendingMatch = nil
	MatchStateService.setArenaBusy(true)
	if MatchReadyBindable then
		MatchReadyBindable:Fire(playerList, modeId)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId }
		broadcastQueue(modeId)
		return
	end

	if modeId == "training" and count >= 1 then
		launchMatch(modeId, popPlayers(modeId, 1))
		return
	end

	if modeId == "pvp" and count >= 2 then
		launchMatch(modeId, popPlayers(modeId, 2))
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			if fillTimers[modeId] then
				task.cancel(fillTimers[modeId])
				fillTimers[modeId] = nil
			end
			launchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
			return
		end

		if count >= mode.minPlayers and not fillTimers[modeId] then
			fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				fillTimers[modeId] = nil
				local current = getQueue(modeId)
				if #current >= mode.minPlayers and not MatchStateService.isArenaBusy() then
					launchMatch(modeId, popPlayers(modeId, #current))
				elseif #current >= mode.minPlayers then
					pendingMatch = { modeId = modeId }
					broadcastQueue(modeId)
				end
			end)
		end
	end
end

local function processPending()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local modeId = pendingMatch.modeId
	pendingMatch = nil
	tryStartMatch(modeId)
end

function MatchmakingService.init(remotes, bindables, callbacks)
	Remotes = remotes
	MatchReadyBindable = bindables.MatchReady
	onQueueChange = callbacks and callbacks.onQueueChange

	MatchStateService.onArenaFree(processPending)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
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
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end

	if playerMode[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		return true
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId

	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	broadcastQueue(modeId)
	Remotes.QueueUpdate:FireClient(player, {
		modeId = modeId,
		inQueue = false,
		status = "left",
	})
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerMode[player]
end

function MatchmakingService.getQueueCount(modeId)
	return #(getQueue(modeId) or {})
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
end

return MatchmakingService
