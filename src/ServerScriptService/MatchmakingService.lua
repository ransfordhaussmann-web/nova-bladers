local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

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

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local size = getQueueSize(modeId)
	local arenaBusy = GameMatchState.isBusy()
	local status = "searching"

	if arenaBusy then
		status = "pending_arena"
	elseif modeId == "ffa" and size >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
		fillSecondsLeft = fillTimers[modeId] and fillTimers[modeId].secondsLeft,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local payload = buildQueuePayload(player, modeId)
	if payload then
		payload.inQueue = true
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates(modeId)
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end

	if getQueueSize(modeId) < MatchModes.get(modeId).minPlayers then
		local timer = fillTimers[modeId]
		if timer then
			timer.cancelled = true
			fillTimers[modeId] = nil
		end
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

local function takePlayersFromQueue(modeId, count)
	local taken = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function startMatch(modeId, playerList)
	local timer = fillTimers[modeId]
	if timer then
		timer.cancelled = true
		fillTimers[modeId] = nil
	end

	for _, player in playerList do
		sendQueueUpdate(player)
		if callbacks.onMatchReady then
			callbacks.onMatchReady(player, modeId)
		end
	end

	Bindables.MatchReady:Fire(modeId, playerList)
end

local function tryStartMatch(modeId)
	if GameMatchState.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	if mode.instantStart and size >= mode.minPlayers then
		local players = takePlayersFromQueue(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			startMatch(modeId, players)
		end
		return
	end

	if modeId == "ffa" then
		if size >= mode.maxPlayers then
			local players = takePlayersFromQueue(modeId, mode.maxPlayers)
			startMatch(modeId, players)
			return
		end

		if size >= mode.minPlayers and not fillTimers[modeId] then
			local token = { cancelled = false, secondsLeft = mode.fillTimeout }
			fillTimers[modeId] = token

			task.spawn(function()
				for remaining = mode.fillTimeout, 1, -1 do
					if token.cancelled or GameMatchState.isBusy() then
						if fillTimers[modeId] == token then
							fillTimers[modeId] = nil
						end
						return
					end
					token.secondsLeft = remaining
					broadcastQueueUpdates(modeId)
					task.wait(1)
				end

				if token.cancelled or GameMatchState.isBusy() then
					if fillTimers[modeId] == token then
						fillTimers[modeId] = nil
					end
					return
				end

				fillTimers[modeId] = nil
				if getQueueSize(modeId) >= mode.minPlayers then
					local players = takePlayersFromQueue(modeId, mode.maxPlayers)
					if #players >= mode.minPlayers then
						startMatch(modeId, players)
					end
				end
			end)
		end
	end
end

local function tryAllQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local modeId = MatchModes.getRecommended(count)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	GameMatchState.setBusy(false)
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
	tryAllQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinRecommended(player)
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
