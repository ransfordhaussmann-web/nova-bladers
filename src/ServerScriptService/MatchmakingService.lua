--[[
	MatchmakingService — per-mode queues, fill timeouts, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingLaunch = {}
local onMatchStart
local started = false

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
		fillTokens[mode.id] = 0
	end
end

local function countValid(players)
	local n = 0
	for _, player in players do
		if player.Parent then
			n += 1
		end
	end
	return n
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId] or {}
	local count = countValid(queue)
	local pending = pendingLaunch[modeId] == true
	local arenaBusy = MatchStateService.isArenaBusy()

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = playerQueue[player] == modeId,
		pending = pending or (arenaBusy and playerQueue[player] == modeId),
		arenaBusy = arenaBusy,
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		local modeId = playerQueue[player]
		if modeId then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		else
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] += 1
	pendingLaunch[modeId] = false
end

local function launchMatch(modeId, playerList)
	pendingLaunch[modeId] = false
	cancelFillTimer(modeId)
	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		removeFromQueue(player)
	end

	if onMatchStart then
		onMatchStart(playerList, modeId)
	end

	MatchReady:Fire(playerList, modeId)
	broadcastQueueUpdate()
end

local function tryLaunch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	local valid = {}
	for _, player in queue do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(valid, player)
		end
	end

	local count = #valid
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingLaunch[modeId] = true
		broadcastQueueUpdate()
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(matchPlayers, valid[i])
	end

	launchMatch(modeId, matchPlayers)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end

		local queue = queues[modeId]
		local count = countValid(queue)
		if count >= mode.minPlayers then
			tryLaunch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] == modeId then
		broadcastQueueUpdate()
		return true
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local count = countValid(queues[modeId])
	if count >= mode.maxPlayers then
		tryLaunch(modeId)
	elseif count >= mode.minPlayers then
		if mode.fillTimeout <= 0 then
			tryLaunch(modeId)
		else
			scheduleFillTimeout(modeId)
		end
	end

	broadcastQueueUpdate()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	cancelFillTimer(modeId)
	broadcastQueueUpdate()
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.setOnMatchStart(callback)
	onMatchStart = callback
end

function MatchmakingService.start(hubCallbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	if started then
		return
	end
	started = true
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.pickForPlayerCount(#Players:GetPlayers()).id
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		for modeId in queues do
			if pendingLaunch[modeId] or countValid(queues[modeId]) >= MatchModes.get(modeId).minPlayers then
				tryLaunch(modeId)
			end
		end
	end)

	if hubCallbacks and hubCallbacks.onModePadTriggered then
		for modeId, trigger in hubCallbacks.onModePadTriggered do
			trigger:Connect(function(player)
				MatchmakingService.joinQueue(player, modeId)
			end)
		end
	end

	if hubCallbacks and hubCallbacks.onPortalTriggered then
		hubCallbacks.onPortalTriggered:Connect(function(player)
			local mode = MatchModes.pickForPlayerCount(#Players:GetPlayers())
			MatchmakingService.joinQueue(player, mode.id)
		end)
	end

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
