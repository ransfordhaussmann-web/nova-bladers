--[[
	MatchmakingService — per-mode queues with fill timers and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {}
local playerEntry = {}
local fillTimers = {}
local callbacks = {}

local function ensureQueues()
	for _, mode in MatchModes.all() do
		if not queues[mode.id] then
			queues[mode.id] = {}
		end
	end
end

local function getFillTimeout(mode)
	if mode.id == "ffa" then
		return MatchmakingConfig.FFA_FILL_TIMEOUT
	elseif mode.id == "pvp" then
		return MatchmakingConfig.PVP_FILL_TIMEOUT
	end
	return nil
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = queues[modeId]
	local count = #queue
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	local fillSecondsLeft = nil
	local timer = fillTimers[modeId]
	if timer and timer.deadline then
		fillSecondsLeft = math.max(0, math.ceil(timer.deadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = count,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = fillSecondsLeft,
		inQueue = playerEntry[player] ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent and HubService.getPhase(player) == "hub" then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer and timer.thread then
		task.cancel(timer.thread)
	end
	fillTimers[modeId] = nil
end

local function removeFromQueue(player)
	local modeId = playerEntry[player]
	if not modeId then
		return
	end

	playerEntry[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if #queue < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(taken, player)
		end
	end
	clearFillTimer(modeId)
	broadcastQueueUpdate(modeId)
	return taken
end

local function fireMatchReady(players, modeId)
	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
	MatchReady:Fire(players, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or #queue == 0 then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.instantStart and #queue >= 1 then
		local players = takePlayersFromQueue(modeId, 1)
		if #players > 0 then
			fireMatchReady(players, modeId)
		end
		return
	end

	if #queue >= mode.maxPlayers then
		local players = takePlayersFromQueue(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			fireMatchReady(players, modeId)
		end
		return
	end

	if #queue >= mode.minPlayers then
		local timer = fillTimers[modeId]
		if not timer then
			local timeout = getFillTimeout(mode)
			if timeout then
				local deadline = os.clock() + timeout
				local thread = task.delay(timeout, function()
					fillTimers[modeId] = nil
					if MatchStateService.isBusy() then
						broadcastQueueUpdate(modeId)
						return
					end
					local current = queues[modeId]
					if #current >= mode.minPlayers then
						local players = takePlayersFromQueue(modeId, math.min(#current, mode.maxPlayers))
						if #players >= mode.minPlayers then
							fireMatchReady(players, modeId)
						end
					end
				end)
				fillTimers[modeId] = { deadline = deadline, thread = thread }
				broadcastQueueUpdate(modeId)
			elseif #queue >= mode.minPlayers then
				local players = takePlayersFromQueue(modeId, mode.minPlayers)
				if #players >= mode.minPlayers then
					fireMatchReady(players, modeId)
				end
			end
		end
	end
end

local function tryAllQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerEntry[player] = modeId

	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.recommendForPlayerCount(count)
	return MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	return MatchModes.recommendForPlayerCount(count).id
end

function MatchmakingService.init(opts)
	callbacks = opts or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ensureQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinRecommended(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onBusyChanged(function(busy)
		if not busy then
			task.defer(tryAllQueues)
		else
			broadcastAllQueues()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in queues do
				if #queues[modeId] > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
