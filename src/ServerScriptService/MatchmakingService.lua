local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local callbacks = {}
local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTimers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getModeLabel(modeId)
	local mode = MatchModes.get(modeId)
	return mode and mode.label or modeId
end

local function isPlayerValid(player)
	return player and player.Parent == Players
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue == 0 and fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if isPlayerValid(queuedPlayer) then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local mode = MatchModes.get(modeId)
	return {
		status = status or "searching",
		modeId = modeId,
		modeLabel = getModeLabel(modeId),
		players = names,
		playerCount = #names,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
	}
end

local function notifyPlayer(player, modeId, status)
	if not isPlayerValid(player) then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if isPlayerValid(queuedPlayer) then
			notifyPlayer(queuedPlayer, modeId, "searching")
		end
	end
end

local function notifyPending(roster)
	for _, player in roster do
		if isPlayerValid(player) then
			Remotes.QueueUpdate:FireClient(player, {
				status = "pending",
				modeLabel = getModeLabel(pendingMatch.modeId),
				modeId = pendingMatch.modeId,
				message = "Arena belegt — warte auf freien Slot...",
			})
		end
	end
end

local function clearQueue(modeId, roster)
	local queue = getQueue(modeId)
	for _, player in roster do
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
		playerQueue[player] = nil
	end

	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
end

local function launchMatch(modeId, roster)
	clearQueue(modeId, roster)
	pendingMatch = nil

	for _, player in roster do
		if callbacks.onJoinArena and isPlayerValid(player) then
			callbacks.onJoinArena(player)
		end
	end

	Bindables.MatchReady:Fire(roster, modeId)
end

local function tryStartMatch(modeId, roster)
	if #roster == 0 then
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			roster = roster,
		}
		notifyPending(roster)
		return
	end

	launchMatch(modeId, roster)
end

local function rosterFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local roster = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[i]
		if isPlayerValid(player) then
			table.insert(roster, player)
		end
	end
	return roster
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local count = math.min(#queue, mode.maxPlayers)
	tryStartMatch(modeId, rosterFromQueue(modeId, count))
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout or fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		evaluateQueue(modeId)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isPlayerValid(player) then
		return false, "invalid_player"
	end

	if callbacks.getPhase and callbacks.getPhase(player) == "arena" then
		return false, "in_match"
	end

	if playerQueue[player] then
		return false, "already_queued"
	end

	local resolvedMode = modeId
	if not resolvedMode or resolvedMode == "auto" then
		resolvedMode = MatchModes.resolveAuto(#Players:GetPlayers())
	end

	local mode = MatchModes.get(resolvedMode)
	if not mode then
		return false, "unknown_mode"
	end

	removeFromQueue(player)

	local queue = getQueue(resolvedMode)
	table.insert(queue, player)
	playerQueue[player] = resolvedMode

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, resolvedMode)
	end

	notifyPlayer(player, resolvedMode, "searching")
	broadcastQueue(resolvedMode)

	if mode.immediate or #queue >= mode.maxPlayers then
		evaluateQueue(resolvedMode)
	elseif mode.fillTimeout and #queue >= mode.minPlayers then
		scheduleFillTimer(resolvedMode)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromQueue(player)

	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end

	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	broadcastQueue(modeId)

	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

local function onArenaFree()
	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		tryStartMatch(match.modeId, match.roster)
		return
	end

	for _, mode in MatchModes.getAll() do
		evaluateQueue(mode.id)
	end
end

local function onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.start(options)
	callbacks = options or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
