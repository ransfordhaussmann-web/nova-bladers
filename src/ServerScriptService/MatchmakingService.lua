local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerQueue = {}
local fillTokens = {}
local handlers = {}

local function ensureQueues()
	for _, modeId in MatchModes.ALL do
		if not queues[modeId] then
			queues[modeId] = {}
		end
	end
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local count = #queues[modeId]
	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode.instant and count >= mode.minPlayers then
		status = "starting"
	elseif count >= mode.maxPlayers then
		status = "starting"
	elseif count >= mode.minPlayers and mode.fillTimeout then
		status = "filling"
	end

	return {
		modeId = modeId,
		label = mode.label,
		desc = mode.desc,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = getQueueStatus(modeId)
	if not payload then
		return
	end

	for _, player in queues[modeId] do
		if player.Parent and playerQueue[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	broadcastQueueUpdate(modeId)

	local mode = MatchModes.get(modeId)
	if mode and #queue < mode.minPlayers then
		cancelFillTimer(modeId)
	end
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local taken = {}

	for i = 1, count do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(taken, player)
	end

	cancelFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	return taken
end

local function startMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end

	local players = takePlayers(modeId)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		broadcastQueueUpdate(modeId)
		return false
	end

	MatchStateService.setArenaBusy(true)

	for _, player in players do
		if handlers.leaveHubForArena then
			handlers.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	return true
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if #queues[modeId] >= mode.minPlayers then
			startMatch(modeId)
		end
	end)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		broadcastQueueUpdate(modeId)
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.instant or #queue >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if mode.fillTimeout then
		if #queue == mode.minPlayers then
			scheduleFillTimeout(modeId)
		end
		if #queue >= mode.maxPlayers then
			startMatch(modeId)
		end
		return
	end

	if #queue >= mode.maxPlayers then
		startMatch(modeId)
	end
end

local function tryStartAllQueues()
	for _, modeId in MatchModes.ALL do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		modeId = handlers.getActiveModeId and handlers.getActiveModeId() or "training"
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(tryStartAllQueues)
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}
	ensureQueues()

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			if MatchStateService.isArenaBusy() then
				broadcastAllQueues()
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
