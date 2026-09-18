local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerMode = {}
local fillTokens = {}

local function initQueues()
	for modeId in MatchModes do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	return #(queues[modeId] or {})
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
	return modeId
end

local function getPlayerNames(modeId)
	local names = {}
	for _, queuedPlayer in queues[modeId] or {} do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.Name)
		end
	end
	return names
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes[modeId]
	if not mode then
		return { inQueue = false }
	end

	local count = getQueueCount(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = count,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = status,
		arenaBusy = MatchStateService.isBusy(),
		players = getPlayerNames(modeId),
	}
end

local function broadcastQueueUpdate(modeId, status)
	for _, queuedPlayer in queues[modeId] or {} do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId, status))
		end
	end
end

local function clearQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	local limit = math.min(count, #queue)
	for _ = 1, limit do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function popMatchPlayers(modeId)
	local mode = MatchModes[modeId]
	if modeId == "training" then
		return takePlayers(modeId, 1)
	elseif modeId == "pvp" then
		return takePlayers(modeId, 2)
	end
	return takePlayers(modeId, math.min(getQueueCount(modeId), mode.maxPlayers))
end

function MatchmakingService.startMatch(modeId, players)
	if #players == 0 then
		return
	end

	cancelFillTimer(modeId)
	MatchStateService.setBusy(true)

	for _, player in players do
		clearQueueUpdate(player)
	end

	MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
end

local function tryStartMatch(modeId)
	local mode = MatchModes[modeId]
	local count = getQueueCount(modeId)
	if not mode or count == 0 then
		return
	end

	local status = if MatchStateService.isBusy() then "pending" else "waiting"
	broadcastQueueUpdate(modeId, status)

	if MatchStateService.isBusy() then
		return
	end

	if modeId == "training" and count >= 1 then
		MatchmakingService.startMatch(modeId, popMatchPlayers(modeId))
		return
	end

	if modeId == "pvp" and count >= 2 then
		MatchmakingService.startMatch(modeId, popMatchPlayers(modeId))
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			MatchmakingService.startMatch(modeId, popMatchPlayers(modeId))
			return
		end

		if count >= mode.minPlayers and not fillTokens[modeId .. "_active"] then
			fillTokens[modeId .. "_active"] = true
			local token = (fillTokens[modeId] or 0) + 1
			fillTokens[modeId] = token

			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				fillTokens[modeId .. "_active"] = nil
				if token ~= fillTokens[modeId] then
					return
				end
				if MatchStateService.isBusy() then
					broadcastQueueUpdate(modeId, "pending")
					return
				end
				if getQueueCount(modeId) >= mode.minPlayers then
					MatchmakingService.startMatch(modeId, popMatchPlayers(modeId))
				end
			end)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes[modeId] then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	local status = if MatchStateService.isBusy() then "pending" else "waiting"
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
	broadcastQueueUpdate(modeId, status)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return
	end

	cancelFillTimer(modeId)
	fillTokens[modeId .. "_active"] = nil
	clearQueueUpdate(player)
	broadcastQueueUpdate(modeId, "waiting")
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	for modeId in MatchModes do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.init()
	local remotesFolder, bindablesFolder = RemotesSetup.ensure()
	Remotes = remotesFolder
	MatchReady = bindablesFolder.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	initQueues()
	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
