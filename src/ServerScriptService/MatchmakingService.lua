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
local playerEntry = {}
local fillTimers = {}

local function initQueues()
	for modeId in MatchModes.getAll() do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if modeId == "quick" or modeId == nil then
		return getRecommendedModeId()
	end
	if MatchModes.isValid(modeId) then
		return modeId
	end
	return getRecommendedModeId()
end

local function buildQueuePayload(modeId)
	local mode = MatchModes.get(modeId)
	local waiting = getQueueCount(modeId)
	local pending = MatchStateService.isBusy()
	return {
		modeId = modeId,
		modeLabel = mode.label,
		waiting = waiting,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = pending and "pending" or "waiting",
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueueUpdate()
	for modeId in MatchModes.getAll() do
		local payload = buildQueuePayload(modeId)
		for _, player in queues[modeId] do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and getQueueCount(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate()
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerEntry[player] = nil
			HubService.setPhase(player, "arena")
			Remotes.HubState:FireClient(player, { phase = "arena", modeLabel = MatchModes.get(modeId).label })
		end
	end
	return picked
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdate()
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	local startCount = math.min(count, mode.maxPlayers)
	if count < mode.maxPlayers and mode.fillTimeout and not fillTimers[modeId] then
		return
	end

	clearFillTimer(modeId)
	local players = popPlayers(modeId, startCount)
	if #players == 0 then
		return
	end

	broadcastQueueUpdate()
	MatchReady:Fire(players, modeId)
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = getQueueCount(modeId)
	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif count >= mode.minPlayers then
		if mode.fillTimeout then
			if not fillTimers[modeId] then
				scheduleFillTimer(modeId)
			end
		else
			tryStartMatch(modeId)
		end
	end

	broadcastQueueUpdate()
end

function MatchmakingService.joinQueue(player, modeId)
	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	modeId = resolveModeId(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId }

	local payload = buildQueuePayload(modeId)
	Remotes.QueueUpdate:FireClient(player, payload)
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end
	removeFromQueue(player)
	Remotes.HubState:FireClient(player, { phase = "hub" })
end

function MatchmakingService.getPlayerQueue(player)
	return playerEntry[player]
end

function MatchmakingService.getRecommendedMode()
	return getRecommendedModeId()
end

function MatchmakingService.onArenaFree()
	for modeId in MatchModes.getAll() do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.init()
	initQueues()

	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "quick"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
