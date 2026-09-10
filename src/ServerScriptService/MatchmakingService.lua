local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local arenaBusy = false
local pendingMatch = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {
		players = {},
		fillToken = 0,
		fillDeadline = nil,
	}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function buildUpdate(player, modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = #queue.players
	local secondsLeft = nil

	if queue.fillDeadline then
		secondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	local status = "waiting"
	if pendingMatch and pendingMatch.modeId == modeId then
		for _, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				status = "pending"
				break
			end
		end
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		status = status,
		playersInQueue = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		secondsLeft = secondsLeft,
		arenaBusy = arenaBusy,
	}
end

local function notifyPlayer(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	for _, player in queue.players do
		notifyPlayer(player, buildUpdate(player, modeId))
	end
end

local function clearFillTimer(modeId)
	local queue = queues[modeId]
	queue.fillToken += 1
	queue.fillDeadline = nil
end

local function removePlayerFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	playerMode[player] = nil

	if pendingMatch then
		for index, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				table.remove(pendingMatch.players, index)
				if #pendingMatch.players == 0 then
					pendingMatch = nil
				end
				break
			end
		end
	end

	local config = getModeConfig(modeId)
	if #queue.players < config.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
	notifyPlayer(player, { status = "left" })
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}

	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end

	clearFillTimer(modeId)
	broadcastQueue(modeId)
	return taken
end

local function markPlayersForArena(players)
	for _, player in players do
		HubService.enterArena(player)
	end
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	local config = getModeConfig(modeId)
	if not config then
		return
	end

	if arenaBusy then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		for _, queuedPlayer in players do
			notifyPlayer(queuedPlayer, {
				modeId = modeId,
				modeLabel = config.label,
				status = "pending",
				playersInQueue = #players,
				minPlayers = config.minPlayers,
				maxPlayers = config.maxPlayers,
				arenaBusy = true,
			})
		end
		return
	end

	markPlayersForArena(players)
	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function tryStartQueue(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = queues[modeId]
	local count = #queue.players

	if count >= config.maxPlayers then
		launchMatch(modeId, takePlayersFromQueue(modeId, config.maxPlayers))
		return
	end

	if count < config.minPlayers then
		return
	end

	if config.fillTimeout <= 0 then
		launchMatch(modeId, takePlayersFromQueue(modeId, count))
		return
	end

	if queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + config.fillTimeout
	queue.fillToken += 1
	local token = queue.fillToken
	broadcastQueue(modeId)

	task.delay(config.fillTimeout, function()
		if queue.fillToken ~= token then
			return
		end

		queue.fillDeadline = nil
		local readyCount = #queue.players
		if readyCount >= config.minPlayers then
			launchMatch(modeId, takePlayersFromQueue(modeId, readyCount))
		else
			broadcastQueue(modeId)
		end
	end)
end

local function tryStartPending()
	if arenaBusy or not pendingMatch then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	launchMatch(match.modeId, match.players)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local config = getModeConfig(modeId)
	if not config then
		return false, "unknown_mode"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	if playerMode[player] then
		MatchmakingService.leaveQueue(player)
	end

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerMode[player] = modeId
	broadcastQueue(modeId)
	tryStartQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end
	removePlayerFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchStarted()
	arenaBusy = true
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	for modeId in queues do
		broadcastQueue(modeId)
	end
	tryStartPending()
end

function MatchmakingService.resolveAutoMode()
	local Players = game:GetService("Players")
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.onMatchStarted()
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

return MatchmakingService
