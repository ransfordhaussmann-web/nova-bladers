local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local HubService

local queues = {}
local playerQueue = {}
local fillTokens = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function buildPlayerUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local arenaBusy = MatchStateService.isArenaBusy()
	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif #queue >= mode.minPlayers then
		status = "ready"
	end

	return {
		inQueue = true,
		modeId = modeId,
		label = mode.label,
		position = position,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		arenaBusy = arenaBusy,
		status = status,
	}
end

local function sendQueueUpdate(player)
	if player.Parent and Remotes then
		Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
	end
end

local function broadcastQueue(modeId)
	local queue = ensureQueue(modeId)
	for _, queuedPlayer in queue do
		sendQueueUpdate(queuedPlayer)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = nil
	sendQueueUpdate(player)
	broadcastQueue(modeId)
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = nil
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	if HubService and HubService.getPhase(player) == "arena" then
		HubService.returnPlayerToHub(player)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	local queue = ensureQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	if HubService and HubService.getPhase(player) ~= "arena" then
		HubService.leaveHubForArena(player)
	end

	broadcastQueue(modeId)

	if mode.instantStart or #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and mode.fillTimeout then
		if not fillTokens[modeId] then
			startFillTimer(modeId)
		end
	else
		cancelFillTimer(modeId)
	end

	return true
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	cancelFillTimer(modeId)

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

function MatchmakingService.init(deps)
	HubService = deps.hubService
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
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

	MatchStateService.onArenaIdle(function()
		for _, mode in MatchModes.all() do
			MatchmakingService.tryStartMatch(mode.id)
		end
	end)
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

return MatchmakingService
