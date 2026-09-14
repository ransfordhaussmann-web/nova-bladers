--[[
	MatchmakingService — per-mode queues with FFA fill timeout and pending matches.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local pendingMatch = nil
local ffaFillDeadline = nil
local heartbeatRunning = false

local onPlayerEnterArena
local onPlayerLeaveHub

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queued in queue do
		if queued == player then
			position = i
			break
		end
	end

	local fillTimeLeft = nil
	if modeId == "ffa" and ffaFillDeadline and #queue >= mode.minPlayers then
		fillTimeLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = MatchStateService.isBusy(),
		fillTimeLeft = fillTimeLeft,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function clearQueueUI(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { cleared = true })
	end
end

local function takeMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	if modeId ~= "ffa" then
		count = mode.minPlayers
	end

	local matchPlayers = {}
	for i = 1, count do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	return matchPlayers
end

local function launchMatch(matchPlayers, modeId)
	for _, player in matchPlayers do
		if onPlayerEnterArena then
			onPlayerEnterArena(player)
		end
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]

	if #queue < mode.minPlayers then
		return
	end

	local shouldStart = false
	if modeId == "ffa" then
		shouldStart = #queue >= mode.maxPlayers
			or (ffaFillDeadline ~= nil and os.clock() >= ffaFillDeadline)
	else
		shouldStart = #queue >= mode.minPlayers
	end

	if not shouldStart then
		return
	end

	local matchPlayers = takeMatchPlayers(modeId)
	ffaFillDeadline = nil

	if #matchPlayers == 0 then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = { modeId = modeId, players = matchPlayers }
		for _, player in matchPlayers do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					pending = true,
					modeId = modeId,
					modeLabel = mode.label,
					total = #matchPlayers,
				})
			end
		end
		return
	end

	launchMatch(matchPlayers, modeId)
end

local function tickQueues()
	for modeId, queue in queues do
		if modeId == "ffa" and #queue >= MatchModes.ffa.minPlayers and ffaFillDeadline then
			tryStartMatch("ffa")
		end
	end

	if pendingMatch and not MatchStateService.isBusy() then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.players, match.modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if playerMode[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if modeId == "ffa" and #queues[modeId] == MatchModes.ffa.minPlayers then
		ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	if onPlayerLeaveHub then
		onPlayerLeaveHub(player)
	end

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	clearQueueUI(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.onArenaFreed()
	if pendingMatch and not MatchStateService.isBusy() then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.players, match.modeId)
	end
end

function MatchmakingService.registerHandlers(handlers)
	onPlayerEnterArena = handlers.onEnterArena
	onPlayerLeaveHub = handlers.onLeaveHub
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

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

	MatchStateService.onArenaFreed(function()
		MatchmakingService.onArenaFreed()
	end)

	if not heartbeatRunning then
		heartbeatRunning = true
		task.spawn(function()
			while true do
				task.wait(MatchmakingConfig.QUEUE_TICK)
				tickQueues()
			end
		end)
	end
end

return MatchmakingService
