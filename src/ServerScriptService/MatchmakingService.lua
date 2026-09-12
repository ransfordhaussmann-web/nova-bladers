--[[
	MatchmakingService — per-mode queues with fill timeout and arena-busy pending state.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchFlowState = require(script.Parent.MatchFlowState)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local remotes = RemotesSetup.ensure()
local onMatchReady = nil
local onPlayersEnterArena = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countPlayersInHub()
	local Players = game:GetService("Players")
	return #Players:GetPlayers()
end

local function resolveModeId(modeId)
	if modeId == "auto" then
		return MatchmakingConfig.resolveAutoMode(countPlayersInHub())
	end
	if getModeConfig(modeId) then
		return modeId
	end
	return "training"
end

local function queueIndex(modeId, player)
	local list = queues[modeId]
	for i, queuedPlayer in list do
		if queuedPlayer == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	local list = queues[modeId]
	local status = MatchmakingConfig.STATUS.Waiting
	if MatchFlowState.arenaBusy and #list >= config.minPlayers then
		status = MatchmakingConfig.STATUS.Pending
	end

	return {
		mode = modeId,
		modeLabel = config.label,
		status = status,
		players = #list,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		position = queueIndex(modeId, player),
		fillTimeout = config.fillTimeout,
	}
end

local function broadcastQueue(modeId)
	if not remotes then
		return
	end
	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
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

	playerQueue[player] = nil
	broadcastQueue(modeId)

	local config = getModeConfig(modeId)
	if #list < config.minPlayers then
		clearFillTimer(modeId)
	end
end

local function takePlayers(modeId)
	local config = getModeConfig(modeId)
	local list = queues[modeId]
	local count = math.min(#list, config.maxPlayers)
	local players = {}

	for i = 1, count do
		local player = list[1]
		table.remove(list, 1)
		playerQueue[player] = nil
		table.insert(players, player)
	end

	clearFillTimer(modeId)
	broadcastQueue(modeId)
	return players
end

local function startMatch(modeId)
	local config = getModeConfig(modeId)
	local list = queues[modeId]
	if #list < config.minPlayers then
		return
	end

	local players = takePlayers(modeId)
	if #players == 0 then
		return
	end

	clearFillTimer(modeId)
	MatchFlowState.arenaBusy = true

	for _, player in players do
		if remotes and player.Parent then
			remotes.QueueUpdate:FireClient(player, {
				mode = modeId,
				modeLabel = config.label,
				status = MatchmakingConfig.STATUS.Starting,
				players = #players,
				needed = config.minPlayers,
				maxPlayers = config.maxPlayers,
			})
		end
	end

	if onPlayersEnterArena then
		onPlayersEnterArena(players)
	end

	if onMatchReady then
		onMatchReady({
			players = players,
			mode = modeId,
		})
	end
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if config.fillTimeout <= 0 then
		startMatch(modeId)
		return
	end

	clearFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	task.delay(config.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		if MatchFlowState.arenaBusy then
			return
		end
		startMatch(modeId)
	end)
end

local function tryStartMatch(modeId)
	if MatchFlowState.arenaBusy then
		broadcastQueue(modeId)
		return
	end

	local config = getModeConfig(modeId)
	local list = queues[modeId]
	if #list < config.minPlayers then
		return
	end

	if config.fillTimeout > 0 then
		if #list >= config.maxPlayers then
			startMatch(modeId)
		elseif not fillTimers[modeId] then
			scheduleFillTimer(modeId)
		end
		return
	end

	startMatch(modeId)
end

function MatchmakingService.registerCallbacks(callbacks)
	onMatchReady = callbacks.onMatchReady
	onPlayersEnterArena = callbacks.onPlayersEnterArena
end

function MatchmakingService.joinQueue(player, modeId)
	if playerQueue[player] then
		removeFromQueue(player)
	end

	modeId = resolveModeId(modeId)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	if remotes and player.Parent then
		remotes.QueueUpdate:FireClient(player, { status = "idle" })
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.onMatchEnded()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

return MatchmakingService
