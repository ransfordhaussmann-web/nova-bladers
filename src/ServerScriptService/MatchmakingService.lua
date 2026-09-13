local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local ArenaFree = Bindables.ArenaFree

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingMatch = nil
local started = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function queueNames(modeId)
	local names = {}
	for _, player in getQueue(modeId) do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function buildPayload(modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #queue,
		min = MatchModes.getMin(modeId),
		max = MatchModes.getMax(modeId),
		status = status or "waiting",
		playerNames = queueNames(modeId),
		fillTimeout = MatchmakingConfig.FILL_TIMEOUT,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId, status)
	local payload = buildPayload(modeId, status)
	for _, player in getQueue(modeId) do
		sendQueueUpdate(player, payload)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	broadcastQueue(modeId, "waiting")
	return modeId
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function markPending(players, modeId)
	local payload = buildPayload(modeId, "pending")
	payload.message = "Arena belegt — warte auf freien Slot"
	for _, player in players do
		sendQueueUpdate(player, payload)
	end
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		markPending(players, modeId)
		return
	end

	for _, player in players do
		HubService.leaveHubForArena(player)
		sendQueueUpdate(player, { status = "starting", modeId = modeId })
	end

	MatchReady:Fire(players, modeId)
end

local function tryStartMode(modeId)
	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if modeId == "training" and #queue >= 1 then
		launchMatch(modeId, takePlayers(modeId, 1))
	elseif modeId == "pvp" and #queue >= 2 then
		launchMatch(modeId, takePlayers(modeId, 2))
	elseif modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			fillTokens[modeId] = nil
			launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		elseif #queue >= mode.minPlayers and not fillTokens[modeId] then
			fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
			local token = fillTokens[modeId]
			broadcastQueue(modeId, "filling")

			task.delay(MatchmakingConfig.FILL_TIMEOUT, function()
				if fillTokens[modeId] ~= token then
					return
				end
				fillTokens[modeId] = nil

				local current = getQueue(modeId)
				if #current >= mode.minPlayers then
					launchMatch(modeId, takePlayers(modeId, math.min(#current, mode.maxPlayers)))
				else
					broadcastQueue(modeId, "waiting")
				end
			end)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		modeId = "training"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	playerQueue[player] = modeId
	table.insert(getQueue(modeId), player)
	broadcastQueue(modeId, "waiting")
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return
	end

	sendQueueUpdate(player, { status = "left", modeId = modeId })

	if modeId == "ffa" then
		local queue = getQueue(modeId)
		if #queue < MatchModes.getMin(modeId) then
			fillTokens[modeId] = nil
		end
	end
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerQueue[player]
end

local function onArenaFree()
	if not pendingMatch then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	launchMatch(match.modeId, match.players)
end

local function onPlayerRemoving(player)
	removeFromQueue(player)

	if pendingMatch then
		for index, queuedPlayer in pendingMatch.players do
			if queuedPlayer == player then
				table.remove(pendingMatch.players, index)
				break
			end
		end
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(onArenaFree)
	Players.PlayerRemoving:Connect(onPlayerRemoving)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
