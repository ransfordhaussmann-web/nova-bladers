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
local playerQueue = {}
local fillTimers = {}
local pendingModes = {}
local callbacks = {}

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if player.Parent and HubService.getPhase(player) == "hub" then
			count += 1
		end
	end
	return count
end

local function collectReadyPlayers(mode)
	local queue = ensureQueue(mode.id)
	local ready = {}
	for _, player in queue do
		if player.Parent and HubService.getPhase(player) == "hub" and #ready < mode.maxPlayers then
			table.insert(ready, player)
		end
	end
	return ready
end

local function removePlayerFromAllQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return
	end

	local queue = ensureQueue(previousMode)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	playerQueue[player] = nil
	fillTimers[previousMode] = nil
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = ensureQueue(modeId)
	local validCount = countValidPlayers(queue)
	local status = "waiting"
	if pendingModes[modeId] and validCount >= mode.minPlayers then
		status = "pending"
	end

	local secondsLeft
	local fillEndsAt = fillTimers[modeId]
	if fillEndsAt and mode.fillTimeout and validCount >= mode.minPlayers then
		secondsLeft = math.max(0, math.ceil(fillEndsAt - os.clock()))
	end

	return {
		inQueue = playerQueue[player] == modeId,
		modeId = modeId,
		modeLabel = mode.label,
		players = validCount,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
end

local function broadcastQueue(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function preparePlayersForMatch(players)
	if callbacks.preparePlayersForMatch then
		callbacks.preparePlayersForMatch(players)
	end
end

local function startMatch(modeId, players)
	local mode = getMode(modeId)
	if not mode or #players < mode.minPlayers then
		return false
	end

	pendingModes[modeId] = false
	fillTimers[modeId] = nil

	for _, player in players do
		removePlayerFromAllQueues(player)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	preparePlayersForMatch(players)
	MatchReady:Fire(players, modeId)
	return true
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local players = collectReadyPlayers(mode)
	if #players < mode.minPlayers then
		pendingModes[modeId] = false
		return
	end

	if MatchStateService.isBusy() then
		pendingModes[modeId] = true
		broadcastQueue(modeId)
		return
	end

	if #players > mode.maxPlayers then
		while #players > mode.maxPlayers do
			table.remove(players)
		end
	end

	startMatch(modeId, players)
end

local function scheduleFillTimeout(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	local queue = ensureQueue(modeId)
	if countValidPlayers(queue) < mode.minPlayers then
		fillTimers[modeId] = nil
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = os.clock() + mode.fillTimeout
	broadcastQueue(modeId)

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] == nil then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	broadcastQueue(modeId)

	local mode = getMode(modeId)
	if not mode then
		return
	end

	local count = countValidPlayers(ensureQueue(modeId))
	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if count >= mode.minPlayers then
		if mode.maxPlayers == mode.minPlayers or mode.id ~= "ffa" then
			tryStartMatch(modeId)
		else
			scheduleFillTimeout(modeId)
		end
	else
		fillTimers[modeId] = nil
		pendingModes[modeId] = false
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	removePlayerFromAllQueues(player)

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	onQueueChanged(modeId)
	sendQueueUpdate(player)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player]
	removePlayerFromAllQueues(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	onQueueChanged(modeId)
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

function MatchmakingService.onArenaFree()
	MatchStateService.setBusy(false)

	for modeId in pairs(queues) do
		if pendingModes[modeId] or countValidPlayers(ensureQueue(modeId)) >= (getMode(modeId) or {}).minPlayers then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.init(options)
	callbacks = options or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removePlayerFromAllQueues(player)
			onQueueChanged(modeId)
		end
	end)
end

return MatchmakingService
