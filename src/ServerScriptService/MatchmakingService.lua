local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTimers = {}
local deps = nil

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function playerInQueue(player)
	return playerEntry[player] ~= nil
end

local function getPlayerStatus(modeId)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	return "waiting"
end

local function buildQueuePayload(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, player in queue.players do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getPlayerStatus(modeId),
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(modeId)
	if not deps or not deps.remotes.QueueUpdate then
		return
	end

	local payload = buildQueuePayload(modeId)
	for _, player in getQueue(modeId).players do
		if player.Parent then
			deps.remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in pairs(queues) do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerEntry[player] = nil
	broadcastQueue(entry.modeId)

	local mode = MatchModes.get(entry.modeId)
	if mode and mode.fillTimeout and #queue.players < mode.minPlayers then
		clearFillTimer(entry.modeId)
	end
end

local function addToQueue(player, modeId)
	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerEntry[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	broadcastQueue(modeId)
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	local limit = math.min(count, #queue.players)

	for _ = 1, limit do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(taken, player)
		end
	end

	broadcastQueue(modeId)
	return taken
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	if #queue.players < mode.minPlayers then
		return false
	end

	if mode.instantStart then
		return true
	end

	if mode.fillTimeout then
		if #queue.players >= mode.maxPlayers then
			return true
		end
		return fillTimers[modeId] == "ready"
	end

	return false
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = "running"
	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= "running" then
			return
		end
		fillTimers[modeId] = "ready"
		broadcastQueue(modeId)
		MatchmakingService.tryStartMatch(modeId)
	end)
end

local function leaveHubForMatch(player)
	if deps and deps.onPlayerEnterArena then
		deps.onPlayerEnterArena(player)
	end
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return false
	end

	if not canStartMode(modeId) then
		return false
	end

	local mode = MatchModes.get(modeId)
	local players = takePlayers(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, player in players do
			addToQueue(player, modeId)
		end
		return false
	end

	clearFillTimer(modeId)

	for _, player in players do
		leaveHubForMatch(player)
	end

	if deps and deps.bindables.MatchReady then
		deps.bindables.MatchReady:Fire(players, modeId)
	end

	broadcastAllQueues()
	return true
end

function MatchmakingService.tryStartAnyMatch()
	if MatchStateService.isArenaBusy() then
		return false
	end

	for _, mode in MatchModes.all() do
		if MatchmakingService.tryStartMatch(mode.id) then
			return true
		end
	end
	return false
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if deps and deps.getPhase and deps.getPhase(player) ~= "hub" then
		return false
	end

	addToQueue(player, modeId)

	local mode = MatchModes.get(modeId)
	local queueSize = #getQueue(modeId).players
	if mode.fillTimeout and queueSize >= mode.minPlayers then
		if queueSize >= mode.maxPlayers then
			clearFillTimer(modeId)
			fillTimers[modeId] = "ready"
		else
			startFillTimer(modeId)
		end
	end

	MatchmakingService.tryStartMatch(modeId)
	return true
end

function MatchmakingService.joinSuggestedQueue(player)
	return MatchmakingService.joinQueue(player, getSuggestedModeId())
end

function MatchmakingService.leaveQueue(player)
	if not playerInQueue(player) then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end
	return buildQueuePayload(entry.modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	broadcastAllQueues()
	task.defer(function()
		MatchmakingService.tryStartAnyMatch()
	end)
end

function MatchmakingService.init(options)
	deps = options

	if deps.remotes.QueueJoin then
		deps.remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
			if typeof(modeId) == "string" then
				MatchmakingService.joinQueue(player, modeId)
			else
				MatchmakingService.joinSuggestedQueue(player)
			end
		end)
	end

	if deps.remotes.QueueLeave then
		deps.remotes.QueueLeave.OnServerEvent:Connect(function(player)
			MatchmakingService.leaveQueue(player)
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if deps.bindables.MatchEnded then
		deps.bindables.MatchEnded.Event:Connect(function()
			MatchmakingService.onMatchEnded()
		end)
	end
end

return MatchmakingService
