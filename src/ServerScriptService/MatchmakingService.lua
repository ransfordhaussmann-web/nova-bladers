--[[
	MatchmakingService — per-mode queues with FFA fill timeout and arena-busy pending.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local arenaBusy = false
local pendingMatches = {}
local fillTimers = {}
local onMatchReady = nil
local broadcastUpdate = nil
local initialized = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {} }
	end
	return queues[modeId]
end

local function getPlayerNames(playerList)
	local names = {}
	for _, player in playerList do
		table.insert(names, player.Name)
	end
	return names
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, p in queue.players do
		if p == player then
			table.remove(queue.players, i)
			break
		end
	end
	playerQueue[player] = nil

	if #queue.players < MatchmakingConfig.getMode(modeId).minPlayers and fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function buildUpdatePayload(modeId, status, fillTimeLeft)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	return {
		mode = modeId,
		modeLabel = mode.label,
		players = getPlayerNames(queue.players),
		count = #queue.players,
		min = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
		fillTimeLeft = fillTimeLeft,
	}
end

local function notifyQueuedPlayers(modeId, status, fillTimeLeft)
	if not broadcastUpdate then
		return
	end
	local payload = buildUpdatePayload(modeId, status, fillTimeLeft)
	for _, player in getQueue(modeId).players do
		if player.Parent then
			broadcastUpdate(player, payload)
		end
	end
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		playerQueue[player] = nil
	end
	queues[modeId] = { players = {} }
	fillTimers[modeId] = nil

	if arenaBusy then
		table.insert(pendingMatches, { modeId = modeId, players = playerList })
		if broadcastUpdate then
			local mode = MatchmakingConfig.getMode(modeId)
			for _, player in playerList do
				if player.Parent then
					broadcastUpdate(player, {
						mode = modeId,
						modeLabel = mode.label,
						players = getPlayerNames(playerList),
						count = #playerList,
						min = mode.minPlayers,
						max = mode.maxPlayers,
						status = "pending",
					})
				end
			end
		end
		return
	end

	arenaBusy = true
	if onMatchReady then
		onMatchReady(playerList, modeId)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		notifyQueuedPlayers(modeId, "waiting")
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			local players = table.clone(queue.players)
			startMatch(modeId, players)
			return
		end

		if not fillTimers[modeId] then
			local token = { cancelled = false }
			fillTimers[modeId] = token
			local deadline = os.clock() + mode.fillTimeout

			task.spawn(function()
				while os.clock() < deadline and not token.cancelled do
					local remaining = math.ceil(deadline - os.clock())
					notifyQueuedPlayers(modeId, "filling", remaining)
					task.wait(0.5)
				end

				if token.cancelled then
					return
				end
				fillTimers[modeId] = nil

				local current = getQueue(modeId)
				if #current.players >= mode.minPlayers then
					local players = table.clone(current.players)
					startMatch(modeId, players)
				else
					notifyQueuedPlayers(modeId, "waiting")
				end
			end)
		else
			local timer = fillTimers[modeId]
			local remaining = mode.fillTimeout
			notifyQueuedPlayers(modeId, "filling", remaining)
		end
		return
	end

	local players = table.clone(queue.players)
	startMatch(modeId, players)
end

function MatchmakingService.registerCallbacks(callbacks)
	onMatchReady = callbacks.onMatchReady
	broadcastUpdate = callbacks.onQueueUpdate
end

function MatchmakingService.init(remotes, bindables)
	if initialized then
		return
	end
	initialized = true

	local Players = game:GetService("Players")

	MatchmakingService.registerCallbacks({
		onMatchReady = function(playerList, modeId)
			bindables.MatchReady:Fire(playerList, modeId)
		end,
		onQueueUpdate = function(player, payload)
			if player.Parent then
				remotes.QueueUpdate:FireClient(player, payload)
			end
		end,
	})

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		remotes.QueueUpdate:FireClient(player, { status = "left" })
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.getMode(modeId) then
		return false, "invalid_mode"
	end

	removeFromQueue(player)
	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end
	removeFromQueue(player)
	notifyQueuedPlayers(modeId, "waiting")
	return true
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

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	if #pendingMatches > 0 then
		local nextMatch = table.remove(pendingMatches, 1)
		arenaBusy = true
		if onMatchReady then
			onMatchReady(nextMatch.players, nextMatch.modeId)
		end
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getQueuePayloadForPlayer(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = #queue.players
	local status = "waiting"
	if arenaBusy and count >= mode.minPlayers then
		status = "pending"
	elseif fillTimers[modeId] then
		status = "filling"
	elseif count >= mode.minPlayers then
		status = "starting"
	end
	return buildUpdatePayload(modeId, status)
end

return MatchmakingService
