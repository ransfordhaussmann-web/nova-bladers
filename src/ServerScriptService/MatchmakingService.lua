local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingMatch = nil
local started = false
local activeModeResolver = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue.players do
			if queuedPlayer == player then
				table.remove(queue.players, i)
				break
			end
		end
		if #queue.players < (getModeConfig(modeId).minPlayers or 1) then
			queue.fillDeadline = nil
			fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
		end
	end

	playerQueue[player] = nil
end

local function buildQueuePayload(modeId, status)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = queue and #queue.players or 0
	local fillSecondsLeft

	if config.fillTimeout and queue and queue.fillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		count = count,
		required = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status or "waiting",
		fillSecondsLeft = fillSecondsLeft,
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function broadcastQueueUpdate(modeId, status)
	local payload = buildQueuePayload(modeId, status)
	for _, player in queues[modeId].players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearQueueForPlayers(playerList)
	for _, player in playerList do
		removeFromQueue(player)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function preparePlayersForMatch(playerList)
	for _, player in playerList do
		if HubService.prepareForArena then
			HubService.prepareForArena(player)
		end
	end
end

local function tryStartMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if GameMatchState.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = playerList,
		}
		broadcastQueueUpdate(modeId, "pending")
		return
	end

	pendingMatch = nil
	clearQueueForPlayers(playerList)
	preparePlayersForMatch(playerList)
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function collectReadyPlayers(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not queue or #queue.players < config.minPlayers then
		return nil
	end

	local ready = {}
	for i = 1, math.min(#queue.players, config.maxPlayers) do
		table.insert(ready, queue.players[i])
	end
	return ready
end

local function isQueueReady(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	if not queue then
		return false
	end

	local count = #queue.players
	if count < config.minPlayers then
		return false
	end

	if config.maxPlayers and count >= config.maxPlayers then
		return true
	end

	if config.fillTimeout and queue.fillDeadline and os.clock() >= queue.fillDeadline then
		return true
	end

	if not config.fillTimeout and count >= config.minPlayers then
		return true
	end

	return false
end

local function maybeStartQueue(modeId)
	if not isQueueReady(modeId) then
		return
	end

	local readyPlayers = collectReadyPlayers(modeId)
	if readyPlayers then
		tryStartMatch(modeId, readyPlayers)
	end
end

local function startFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config.fillTimeout then
		return
	end

	local queue = queues[modeId]
	if not queue or queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + config.fillTimeout
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.spawn(function()
		while fillTokens[modeId] == token and queue.fillDeadline do
			local remaining = queue.fillDeadline - os.clock()
			if remaining <= 0 then
				break
			end
			broadcastQueueUpdate(modeId, GameMatchState.isBusy() and "pending" or "waiting")
			task.wait(1)
		end
		if fillTokens[modeId] == token then
			maybeStartQueue(modeId)
		end
	end)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {}, fillDeadline = nil }
	end
	return queues[modeId]
end

function MatchmakingService.joinQueue(player, modeId, getActiveModeId)
	if modeId == "quick" then
		modeId = (getActiveModeId and getActiveModeId()) or resolveQuickMatchMode()
	end
	if not isValidMode(modeId) then
		return
	end
	if playerQueue[player] then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	local config = getModeConfig(modeId)
	if config.fillTimeout and #queue.players >= config.minPlayers then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId, GameMatchState.isBusy() and "pending" or "waiting")

	if config.minPlayers == config.maxPlayers and #queue.players >= config.minPlayers then
		maybeStartQueue(modeId)
	elseif not config.fillTimeout and #queue.players >= config.minPlayers then
		maybeStartQueue(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })

	if queues[modeId] and #queues[modeId].players > 0 then
		broadcastQueueUpdate(modeId, GameMatchState.isBusy() and "pending" or "waiting")
	end
end

local function resolveQuickMatchMode()
	if MatchmakingConfig.QUICK_MATCH_USE_ACTIVE_MODE then
		local count = #Players:GetPlayers()
		if count >= 3 then
			return "ffa"
		elseif count == 2 then
			return "pvp"
		end
	end
	return "training"
end

local function onArenaFree()
	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		tryStartMatch(match.modeId, match.players)
		return
	end

	for modeId in pairs(queues) do
		maybeStartQueue(modeId)
	end
end

function MatchmakingService.start(getActiveModeId)
	if started then
		return
	end
	started = true
	activeModeResolver = getActiveModeId

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId, activeModeResolver)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
