--[[
	Server-side matchmaking queue: mode pads, portal, and lobby quick-match.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingStarts = {}

local hubCallbacks = {}

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function playerInQueue(player)
	return playerQueue[player] ~= nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if #queue < (getMode(modeId) and getMode(modeId).minPlayers or 1) then
		cancelFillTimer(modeId)
		clearPending(modeId)
	end
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local pending = pendingStarts[modeId] ~= nil
	local fillEndsAt = fillTokens[modeId]

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pendingArena = pending and MatchStateService.isArenaBusy(),
		fillEndsAt = fillEndsAt,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueForMode(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = nil
end

local function clearPending(modeId)
	pendingStarts[modeId] = nil
end

local function leaveQueue(player)
	if not playerInQueue(player) then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	cancelFillTimer(modeId)
	clearPending(modeId)
	sendQueueUpdate(player)
	broadcastQueueForMode(modeId)
end

local function setPlayersArenaPhase(players)
	for _, player in players do
		if hubCallbacks.leaveHubForArena then
			hubCallbacks.leaveHubForArena(player)
		end
	end
end

local function launchMatch(modeId, players)
	cancelFillTimer(modeId)
	clearPending(modeId)

	for _, player in players do
		removeFromQueue(player)
	end

	setPlayersArenaPhase(players)
	MatchReady:Fire({
		players = players,
		mode = modeId,
	})
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		clearPending(modeId)
		return
	end

	if #queue > mode.maxPlayers then
		while #queue > mode.maxPlayers do
			local overflow = table.remove(queue)
			playerQueue[overflow] = nil
			sendQueueUpdate(overflow)
		end
	end

	local players = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(players, queue[i])
	end

	if #players < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		if not pendingStarts[modeId] then
			pendingStarts[modeId] = true
			broadcastQueueForMode(modeId)
			task.spawn(function()
				while pendingStarts[modeId] and MatchStateService.isArenaBusy() do
					task.wait(MatchmakingConfig.ARENA_PENDING_POLL)
				end
				if pendingStarts[modeId] and not MatchStateService.isArenaBusy() then
					tryStartMatch(modeId)
				end
			end)
		end
		return
	end

	launchMatch(modeId, players)
end

local function scheduleFillTimeout(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	local endsAt = os.clock() + mode.fillTimeout
	fillTokens[modeId] = endsAt

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= endsAt then
			return
		end
		fillTokens[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	if hubCallbacks.getPhase and hubCallbacks.getPhase(player) ~= "hub" then
		return
	end

	if playerInQueue(player) then
		if playerQueue[player] == modeId then
			sendQueueUpdate(player)
			return
		end
		leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueForMode(modeId)

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and not mode.fillTimeout then
		tryStartMatch(modeId)
	elseif #queue >= mode.minPlayers and mode.fillTimeout and not fillTokens[modeId] then
		scheduleFillTimeout(modeId)
	end
end

local function resolveQuickMatchMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init(hub, callbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	hubCallbacks = callbacks or {}

	for _, mode in MatchModes.getAll() do
		ensureQueue(mode.id)
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = resolveQuickMatchMode()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	if hub and hub.portalPrompt then
		hub.portalPrompt.Triggered:Connect(function(player)
			joinQueue(player, resolveQuickMatchMode())
		end)
	end

	if hub and hub.modePads then
		for _, pad in hub.modePads do
			if pad.prompt then
				pad.prompt.Triggered:Connect(function(player)
					joinQueue(player, pad.config.id)
				end)
			end
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		if playerInQueue(player) then
			leaveQueue(player)
		end
	end)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = resolveQuickMatchMode()
	end
	joinQueue(player, modeId)
end

return MatchmakingService
