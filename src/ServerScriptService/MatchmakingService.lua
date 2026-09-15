--[[
	MatchmakingService — per-mode queues with fill timeouts and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local callbacks = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function playerNames(playerList)
	local names = {}
	for _, player in playerList do
		table.insert(names, player.Name)
	end
	return names
end

local function buildUpdatePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local fillTimeLeft = nil

	local timer = fillTimers[modeId]
	if timer and timer.deadline then
		fillTimeLeft = math.max(0, math.ceil(timer.deadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = playerNames(queue),
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastModeQueue(modeId, status)
	local payload = buildUpdatePayload(modeId, status)
	for _, player in getQueue(modeId) do
		broadcastQueue(player, payload)
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer and timer.thread then
		task.cancel(timer.thread)
	end
	fillTimers[modeId] = nil
end

local function getQueueStatus(modeId)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count >= mode.maxPlayers then
		return "starting"
	end
	if mode.fillTimeout and fillTimers[modeId] and fillTimers[modeId].expired then
		return "starting"
	end
	if count >= mode.minPlayers and not mode.fillTimeout then
		return "starting"
	end
	return "waiting"
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastModeQueue(modeId, getQueueStatus(modeId))
end

local function canStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout and fillTimers[modeId] and fillTimers[modeId].expired then
		return true
	end
	if not mode.fillTimeout and count >= mode.minPlayers then
		return true
	end
	return false
end

local function popMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local matchPlayers = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	for i = #matchPlayers, 1, -1 do
		table.remove(queue, i)
	end

	clearFillTimer(modeId)
	return matchPlayers
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastModeQueue(modeId, "pending")
		return
	end

	if not canStartMatch(modeId) then
		broadcastModeQueue(modeId, getQueueStatus(modeId))
		return
	end

	local matchPlayers = popMatchPlayers(modeId)
	if #matchPlayers == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in matchPlayers do
		broadcastQueue(player, {
			modeId = modeId,
			status = "starting",
			arenaBusy = false,
		})
	end

	if callbacks.onMatchStart then
		callbacks.onMatchStart(matchPlayers, modeId)
	end

	Bindables.MatchReady:Fire({
		players = matchPlayers,
		mode = modeId,
	})

	for otherModeId in queues do
		if otherModeId ~= modeId and #getQueue(otherModeId) > 0 then
			broadcastModeQueue(otherModeId, "pending")
		end
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	local existing = fillTimers[modeId]
	if existing and not existing.expired then
		return
	end

	clearFillTimer(modeId)

	local timer = {
		deadline = os.clock() + mode.fillTimeout,
		expired = false,
	}

	timer.thread = task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= timer then
			return
		end
		timer.expired = true
		tryStartMatch(modeId)
	end)

	fillTimers[modeId] = timer
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local status = getQueueStatus(modeId)
	broadcastQueue(player, buildUpdatePayload(modeId, status))

	if #queue >= mode.minPlayers and mode.fillTimeout then
		startFillTimer(modeId)
		broadcastModeQueue(modeId, getQueueStatus(modeId))
	end

	tryStartMatch(modeId)
	return true
end

local function leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

local function onArenaFreed()
	for modeId in queues do
		if #getQueue(modeId) > 0 then
			broadcastModeQueue(modeId, getQueueStatus(modeId))
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.start(options)
	if started then
		return
	end
	started = true
	callbacks = options or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
			if callbacks.resolveDefaultMode then
				modeId = callbacks.resolveDefaultMode(player)
			else
				modeId = "training"
			end
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			for modeId in queues do
				if #getQueue(modeId) > 0 then
					local status = getQueueStatus(modeId)
					if status == "waiting" or status == "pending" then
						broadcastModeQueue(modeId, status)
					end
				end
			end
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	onArenaFreed()
end

function MatchmakingService.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
