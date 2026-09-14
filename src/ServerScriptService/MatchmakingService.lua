local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady
local ArenaFree

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local queueMeta = {
	training = { fillStartedAt = nil },
	pvp = { fillStartedAt = nil },
	ffa = { fillStartedAt = nil },
}

local playerQueue = {}
local started = false

local function getFillTimeout(modeId)
	if modeId == "ffa" then
		return MatchmakingConfig.FFA_FILL_TIMEOUT
	elseif modeId == "pvp" then
		return MatchmakingConfig.PVP_FILL_TIMEOUT
	end
	return MatchmakingConfig.TRAINING_START_DELAY
end

local function modeLabel(modeId)
	local mode = MatchModes.get(modeId)
	return mode and mode.label or modeId
end

local function countValid(entries)
	local n = 0
	for _, player in entries do
		if player.Parent and HubService.getPhase(player) == "hub" then
			n += 1
		end
	end
	return n
end

local function getValidPlayers(entries, maxCount)
	local result = {}
	for _, player in entries do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(result, player)
			if maxCount and #result >= maxCount then
				break
			end
		end
	end
	return result
end

local function buildUpdatePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local entries = queues[modeId] or {}
	local validCount = countValid(entries)
	local status = "waiting"
	local message = string.format("%s — %d/%d in Warteschlange", modeLabel(modeId), validCount, mode and mode.maxPlayers or 0)

	if GameMatchState.isBusy() then
		status = "pending"
		message = "Arena belegt — du bist in der Warteschlange"
	elseif mode and validCount >= mode.minPlayers then
		local meta = queueMeta[modeId]
		if meta and meta.fillStartedAt then
			local timeout = getFillTimeout(modeId)
			local remaining = math.max(0, timeout - (os.clock() - meta.fillStartedAt))
			if remaining > 0 and validCount < mode.maxPlayers then
				status = "filling"
				message = string.format("Match startet in %ds (%d/%d)", math.ceil(remaining), validCount, mode.maxPlayers)
			else
				status = "ready"
				message = "Match startet gleich..."
			end
		end
	end

	return {
		modeId = modeId,
		status = status,
		queueCount = validCount,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		message = message,
		inQueue = true,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] or {} do
		if playerQueue[player] == modeId then
			sendQueueUpdate(player)
		end
	end
end

local function clearFillTimer(modeId)
	if queueMeta[modeId] then
		queueMeta[modeId].fillStartedAt = nil
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local entries = queues[modeId]
	if entries then
		for i, queued in entries do
			if queued == player then
				table.remove(entries, i)
				break
			end
		end
	end

	if countValid(entries) == 0 then
		clearFillTimer(modeId)
	end

	if not silent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		broadcastQueue(modeId)
	end
end

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function launchMatch(modeId, playerList)
	GameMatchState.setBusy(true)
	clearFillTimer(modeId)

	for _, player in playerList do
		removeFromQueue(player, true)
		leaveHubForArena(player)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end

	MatchReady:Fire(playerList, modeId)
end

local function tryStartQueue(modeId)
	if GameMatchState.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local players = getValidPlayers(queues[modeId], mode.maxPlayers)
	if #players < mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	local meta = queueMeta[modeId]
	if not meta.fillStartedAt then
		meta.fillStartedAt = os.clock()
		broadcastQueue(modeId)
		return
	end

	local timeout = getFillTimeout(modeId)
	local elapsed = os.clock() - meta.fillStartedAt
	local filled = #players >= mode.maxPlayers
	local timedOut = elapsed >= timeout

	if filled or timedOut then
		launchMatch(modeId, players)
	end
end

local function evaluateQueues()
	for modeId in queues do
		tryStartQueue(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	playerQueue[player] = modeId
	table.insert(queues[modeId], player)

	local mode = MatchModes.get(modeId)
	if countValid(queues[modeId]) >= mode.minPlayers and not queueMeta[modeId].fillStartedAt then
		queueMeta[modeId].fillStartedAt = os.clock()
	end

	sendQueueUpdate(player)
	broadcastQueue(modeId)
	evaluateQueues()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	broadcastQueue(modeId)
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	task.defer(evaluateQueues)
end

function MatchmakingService.onMatchStarted()
	GameMatchState.setBusy(true)
	for modeId in queues do
		broadcastQueue(modeId)
	end
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

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ArenaFree = Bindables.ArenaFree

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.TICK_INTERVAL)
			evaluateQueues()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
