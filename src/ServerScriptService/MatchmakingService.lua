--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}
local fillThreads = {}
local callbacks = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function buildQueuePayload(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #names,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		playerNames = names,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function sendQueueUpdate(player)
	local entry = playerQueue[player]
	if not entry or not player.Parent then
		return
	end

	local payload = buildQueuePayload(entry.modeId)
	payload.status = if MatchStateService.isArenaBusy() then "pending" else "waiting"
	payload.position = 0
	for i, queuedPlayer in getQueue(entry.modeId) do
		if queuedPlayer == player then
			payload.position = i
			break
		end
	end

	QueueUpdate:FireClient(player, payload)
end

local function broadcastQueueUpdate(modeId)
	for player, entry in playerQueue do
		if entry.modeId == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillThreads[modeId] = nil
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	local i = 1
	while i <= #queue and #picked < count do
		local player = queue[i]
		if player.Parent and playerQueue[player] and playerQueue[player].modeId == modeId then
			table.insert(picked, player)
			table.remove(queue, i)
			playerQueue[player] = nil
		else
			table.remove(queue, i)
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	cancelFillTimer(modeId)
	broadcastQueueUpdate(modeId)

	if callbacks.onMatchLaunch then
		for _, player in playerList do
			callbacks.onMatchLaunch(player)
		end
	end

	MatchReady:Fire(modeId, playerList)
end

local function canStartMode(mode)
	local queue = getQueue(mode.id)
	return #queue >= mode.minPlayers
end

local function shouldStartImmediately(mode)
	if mode.id == "training" or mode.id == "pvp" then
		return #getQueue(mode.id) >= mode.maxPlayers
	end
	return false
end

local function startFillTimer(mode)
	if fillThreads[mode.id] then
		return
	end

	fillTokens[mode.id] = (fillTokens[mode.id] or 0) + 1
	local token = fillTokens[mode.id]
	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT

	fillThreads[mode.id] = true
	task.spawn(function()
		local deadline = os.clock() + timeout
		while os.clock() < deadline do
			if token ~= fillTokens[mode.id] then
				fillThreads[mode.id] = nil
				return
			end
			if MatchStateService.isArenaBusy() then
				task.wait(0.25)
				continue
			end
			local queue = getQueue(mode.id)
			if #queue >= mode.maxPlayers then
				break
			end
			if #queue < mode.minPlayers then
				fillThreads[mode.id] = nil
				return
			end
			task.wait(0.25)
		end

		fillThreads[mode.id] = nil
		if token ~= fillTokens[mode.id] or MatchStateService.isArenaBusy() then
			return
		end

		local queue = getQueue(mode.id)
		if #queue < mode.minPlayers then
			return
		end

		local takeCount = math.min(#queue, mode.maxPlayers)
		local players = popPlayers(mode.id, takeCount)
		launchMatch(mode.id, players)
	end)
end

local function tryFormMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode or not canStartMode(mode) then
		broadcastQueueUpdate(modeId)
		return
	end

	if shouldStartImmediately(mode) then
		local players = popPlayers(modeId, mode.maxPlayers)
		launchMatch(modeId, players)
		return
	end

	if mode.id == "ffa" then
		if not fillThreads[modeId] then
			startFillTimer(mode)
		end
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.id == "training" then
		local players = popPlayers(modeId, 1)
		launchMatch(modeId, players)
	end
end

local function tryAllQueues()
	for modeId, _ in queues do
		tryFormMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = { modeId = modeId }
	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
	tryFormMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return false
	end

	local modeId = entry.modeId
	removeFromQueue(player)

	if modeId == "ffa" and #getQueue(modeId) < MatchModes.get("ffa").minPlayers then
		cancelFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	QueueUpdate:FireClient(player, { status = "left" })
	return true
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.init(handlers)
	callbacks = handlers or {}

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		task.defer(tryAllQueues)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
