--[[
	MatchmakingService — per-mode queues, fill timers, arena-busy pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local arenaBusy = false
local pendingMatch = nil

local remotes = nil
local bindables = nil
local onMatchDispatch = nil
local initialized = false
local matchEndedWired = false

local dispatchMatch
local evaluateMode

local function onMatchEnded()
	arenaBusy = false

	if pendingMatch then
		local pending = pendingMatch
		pendingMatch = nil
		dispatchMatch(pending.modeId, pending.players)
		return
	end

	for modeId in MatchmakingConfig.MODES do
		evaluateMode(modeId)
	end
end

local function wireMatchEnded()
	if matchEndedWired or not bindables or not bindables.MatchEnded then
		return
	end
	matchEndedWired = true
	bindables.MatchEnded.Event:Connect(onMatchEnded)
end

local function ensureInitialized()
	if initialized then
		return
	end
	local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
	remotes, bindables = RemotesSetup.ensure()
	initialized = true
	wireMatchEnded()
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function playerNameList(modeId)
	local list = {}
	for _, player in ensureQueue(modeId) do
		if player.Parent then
			table.insert(list, player.Name)
		end
	end
	return list
end

local function buildUpdate(player, modeId, status)
	local mode = getModeConfig(modeId)
	local queue = ensureQueue(modeId)
	local inQueue = false
	for _, queued in queue do
		if queued == player then
			inQueue = true
			break
		end
	end

	return {
		inQueue = inQueue,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueSize = #queue,
		required = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status or (arenaBusy and inQueue and "pending" or "waiting"),
		playerNames = playerNameList(modeId),
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	if not remotes then
		return
	end

	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildUpdate(player, modeId))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = ensureQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	clearFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	return modeId
end

dispatchMatch = function(modeId, matchedPlayers)
	arenaBusy = true
	clearFillTimer(modeId)

	local roster = {}
	for _, player in matchedPlayers do
		if player.Parent then
			table.insert(roster, player)
			removeFromQueue(player)
		end
	end

	if #roster == 0 then
		arenaBusy = false
		return
	end

	if onMatchDispatch then
		onMatchDispatch(roster, modeId)
	end

	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(roster, modeId)
	end
end

local function tryStartMode(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local matched = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matched, queue[i])
	end

	if arenaBusy then
		pendingMatch = { modeId = modeId, players = matched }
		for _, player in matched do
			if player.Parent and remotes then
				remotes.QueueUpdate:FireClient(player, buildUpdate(player, modeId, "pending"))
			end
		end
		return
	end

	dispatchMatch(modeId, matched)
end

local function scheduleFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if not mode or not mode.fillTimeout then
		tryStartMode(modeId)
		return
	end

	clearFillTimer(modeId)
	local token = { cancelled = false }
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if token.cancelled or fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMode(modeId)
	end)
end

evaluateMode = function(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue >= mode.maxPlayers then
		tryStartMode(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout then
			if not fillTimers[modeId] then
				scheduleFillTimer(modeId)
			end
		else
			tryStartMode(modeId)
		end
	end
end

function MatchmakingService.init(remotesFolder, bindablesFolder, dispatchHandler)
	remotes = remotesFolder
	bindables = bindablesFolder
	onMatchDispatch = dispatchHandler
	initialized = true
	wireMatchEnded()
end

function MatchmakingService.joinQueue(player, modeId)
	ensureInitialized()
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	if arenaBusy and playerQueue[player] then
		return false, "arena_busy"
	end

	removeFromQueue(player)
	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)
	evaluateMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	ensureInitialized()
	local modeId = removeFromQueue(player)
	if modeId and remotes then
		remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			modeId = nil,
			status = "idle",
		})
	end
	return modeId ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
	if pendingMatch then
		local filtered = {}
		for _, p in pendingMatch.players do
			if p ~= player and p.Parent then
				table.insert(filtered, p)
			end
		end
		pendingMatch.players = filtered
		local mode = getModeConfig(pendingMatch.modeId)
		if not mode or #filtered < mode.minPlayers then
			pendingMatch = nil
		end
	end
end

function MatchmakingService.getSuggestedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
