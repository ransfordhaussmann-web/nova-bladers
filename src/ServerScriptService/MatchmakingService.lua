local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, _ = RemotesSetup.ensure()
local onMatchReady
local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false

local function initQueues()
	for _, modeId in MatchModes.ORDERED do
		queues[modeId] = {}
	end
end

local function getQueueList(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromAllQueues(player)
	local previousMode = playerQueue[player]
	playerQueue[player] = nil

	for modeId, list in queues do
		for i = #list, 1, -1 do
			if list[i] == player then
				table.remove(list, i)
			end
		end
	end

	if previousMode then
		MatchmakingService.broadcastQueueUpdate(previousMode)
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local list = getQueueList(modeId)
	local fillLeft = fillTimers[modeId] and fillTimers[modeId].secondsLeft or nil

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		fillSecondsLeft = fillLeft,
		pendingArena = MatchStateService.isArenaBusy(),
	}
end

function MatchmakingService.broadcastQueueUpdate(modeId)
	local list = getQueueList(modeId)
	for _, player in list do
		if player.Parent then
			local status = "waiting"
			if MatchStateService.isArenaBusy() then
				status = "pending"
			elseif modeId == "ffa" and fillTimers[modeId] then
				status = "starting"
			end
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function fireQueueUpdate(player, modeId, status)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
	end
end

local function fireQueueLeft(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local count = math.min(#list, mode.maxPlayers)
	local ready = {}
	for i = 1, count do
		table.insert(ready, list[i])
	end
	return ready
end

local function clearModeTimers(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function startMatch(modeId)
	if MatchStateService.isArenaBusy() then
		MatchmakingService.broadcastQueueUpdate(modeId)
		return
	end

	local ready = collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	if #ready < mode.minPlayers then
		return
	end

	clearModeTimers(modeId)

	for _, player in ready do
		removeFromAllQueues(player)
		fireQueueLeft(player)
	end

	MatchStateService.setArenaBusy(true)
	if onMatchReady then
		onMatchReady(ready, modeId)
	end
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)

	if #list < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		MatchmakingService.broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "training" or modeId == "pvp" then
		if #list >= mode.maxPlayers then
			startMatch(modeId)
		end
		return
	end

	if modeId == "ffa" then
		if #list >= mode.maxPlayers then
			startMatch(modeId)
			return
		end

		if fillTimers[modeId] then
			return
		end

		fillTimers[modeId] = {
			cancelled = false,
			secondsLeft = MatchmakingConfig.FFA_FILL_TIMEOUT,
		}

		task.spawn(function()
			local remaining = MatchmakingConfig.FFA_FILL_TIMEOUT
			while remaining > 0 do
				local timer = fillTimers[modeId]
				if not timer or timer.cancelled then
					return
				end
				timer.secondsLeft = remaining
				MatchmakingService.broadcastQueueUpdate(modeId)

				if #getQueueList(modeId) >= mode.maxPlayers then
					startMatch(modeId)
					return
				end

				task.wait(1)
				remaining -= 1
			end

			if fillTimers[modeId] and not fillTimers[modeId].cancelled then
				fillTimers[modeId] = nil
				startMatch(modeId)
			end
		end)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		fireQueueUpdate(player, modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
		return true
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local list = getQueueList(modeId)
	table.insert(list, player)
	playerQueue[player] = modeId

	local status = MatchStateService.isArenaBusy() and "pending" or "waiting"
	fireQueueUpdate(player, modeId, status)
	MatchmakingService.broadcastQueueUpdate(modeId)

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromAllQueues(player)
	fireQueueLeft(player)

	local list = getQueueList(modeId)
	if #list < MatchModes.get(modeId).minPlayers then
		clearModeTimers(modeId)
	end

	MatchmakingService.broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	for _, modeId in MatchModes.ORDERED do
		tryStartMode(modeId)
		MatchmakingService.broadcastQueueUpdate(modeId)
	end
end

function MatchmakingService.start(matchReadyCallback)
	if started then
		return
	end
	started = true
	onMatchReady = matchReadyCallback

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for _, modeId in MatchModes.ORDERED do
				if #getQueueList(modeId) > 0 then
					MatchmakingService.broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)
end

initQueues()

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

return MatchmakingService
