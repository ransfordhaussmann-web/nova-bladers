local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTimers = {}
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isValidPlayer(player)
	return player and player.Parent and HubService.getPhase(player) == "hub"
end

local function pruneQueue(modeId)
	local queue = getQueue(modeId)
	local cleaned = {}
	for _, player in queue do
		if isValidPlayer(player) then
			table.insert(cleaned, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = cleaned
end

local function getQueueNames(modeId)
	pruneQueue(modeId)
	local names = {}
	for _, player in getQueue(modeId) do
		table.insert(names, player.DisplayName)
	end
	return names
end

local function buildUpdatePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local pending = pendingMatch ~= nil and pendingMatch.modeId == entry.modeId

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		players = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 6,
		playerNames = getQueueNames(entry.modeId),
		pending = pending,
		fillTimeLeft = fillTimers[entry.modeId],
	}
end

local function broadcastQueueUpdate(modeId)
	pruneQueue(modeId)
	for _, player in getQueue(modeId) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
		end
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local deadline = MatchmakingConfig.FFA_FILL_TIMEOUT
	fillTimers[modeId] = deadline

	task.spawn(function()
		while fillTimers[modeId] and fillTimers[modeId] > 0 do
			task.wait(1)
			if not fillTimers[modeId] then
				return
			end
			fillTimers[modeId] -= 1
			broadcastQueueUpdate(modeId)
		end

		if fillTimers[modeId] == 0 then
			clearFillTimer(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(entry.modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	local mode = MatchModes.get(entry.modeId)
	if mode and #queue < mode.minPlayers then
		clearFillTimer(entry.modeId)
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdate(entry.modeId)
end

local function leaveHubForArena(player)
	if HubService.leaveHubForArena then
		HubService.leaveHubForArena(player)
	end
end

function MatchmakingService.tryStartMatch(modeId)
	pruneQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = table.clone(queue),
		}
		broadcastQueueUpdate(modeId)
		return false
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end
	clearFillTimer(modeId)
	pendingMatch = nil

	for _, player in matchPlayers do
		leaveHubForArena(player)
	end

	MatchReady:Fire(matchPlayers, modeId)
	return true
end

local function processQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	pruneQueue(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if mode.instantStart and #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
		return
	end

	if not mode.instantStart then
		if #queue >= mode.maxPlayers then
			MatchmakingService.tryStartMatch(modeId)
		elseif #queue >= mode.minPlayers then
			startFillTimer(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "not_in_hub"
	end

	if MatchStateService.isArenaBusy() and not playerQueue[player] then
		-- Allow joining queue while arena is busy; match starts when arena frees.
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = { modeId = modeId }

	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	broadcastQueueUpdate(modeId)
	processQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local modeId = "training"
	if count >= 3 then
		modeId = "ffa"
	elseif count >= 2 then
		modeId = "pvp"
	end
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

local function flushPending()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local modeId = pendingMatch.modeId
	pruneQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		pendingMatch = nil
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		pendingMatch = nil
		broadcastQueueUpdate(modeId)
		return
	end

	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	MatchStateService.onArenaIdle(function()
		task.defer(flushPending)
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
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

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
