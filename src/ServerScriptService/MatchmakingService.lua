--[[
	MatchmakingService — per-mode queues with fill timers and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady
local MatchEnded

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTokens = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil
end

local function queueIndex(modeId, player)
	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local index = queueIndex(modeId, player)

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = index,
		pending = MatchStateService.isBusy(),
		inQueue = index ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMode(modeId, true)
	end)
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
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

function MatchmakingService.tryStartMode(modeId, forceStart)
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or #queue < mode.minPlayers then
		return false
	end

	local needed
	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			needed = mode.maxPlayers
		elseif forceStart and #queue >= mode.minPlayers then
			needed = #queue
		else
			broadcastQueueUpdate(modeId)
			return false
		end
	elseif modeId == "pvp" then
		if #queue < mode.minPlayers then
			return false
		end
		needed = MatchmakingConfig.PVP_PLAYERS
	else
		needed = MatchmakingConfig.TRAINING_PLAYERS
	end

	cancelFillTimer(modeId)
	local players = takePlayers(modeId, needed)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	MatchReady:Fire(modeId, players)

	for _, modeKey in { "training", "pvp", "ffa" } do
		broadcastQueueUpdate(modeKey)
	end

	return true
end

local function maybeScheduleFill(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode then
		return
	end

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMode(modeId)
		return
	end

	if modeId == "training" and #queue >= mode.minPlayers then
		MatchmakingService.tryStartMode(modeId, true)
		return
	end

	if modeId == "pvp" and #queue >= mode.minPlayers then
		MatchmakingService.tryStartMode(modeId, true)
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			MatchmakingService.tryStartMode(modeId, true)
		elseif #queue >= mode.minPlayers then
			startFillTimer(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end
	if playerMode[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerMode[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)
	maybeScheduleFill(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	if mode and #getQueue(modeId) < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, {
		modeId = modeId,
		inQueue = false,
		pending = false,
	})
end

function MatchmakingService.isInQueue(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(function()
		for _, modeId in { "training", "pvp", "ffa" } do
			local mode = MatchModes.get(modeId)
			local queue = getQueue(modeId)
			if mode and #queue >= mode.minPlayers then
				if modeId == "ffa" and #queue < mode.maxPlayers then
					startFillTimer(modeId)
				else
					MatchmakingService.tryStartMode(modeId, true)
				end
			end
		end
	end)
end

function MatchmakingService.init()
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			local count = #Players:GetPlayers()
			if count >= 3 then
				modeId = "ffa"
			elseif count == 2 then
				modeId = "pvp"
			else
				modeId = "training"
			end
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
