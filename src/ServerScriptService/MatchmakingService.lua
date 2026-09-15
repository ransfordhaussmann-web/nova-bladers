local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable

local queues = {}
local playerQueue = {}
local ffaFillTokens = {}

local function initQueues()
	for modeId in MatchModes do
		if typeof(MatchModes[modeId]) == "table" and MatchModes[modeId].id then
			queues[modeId] = {
				players = {},
				pending = false,
				fillEndsAt = nil,
			}
			ffaFillTokens[modeId] = 0
		end
	end
end

local function getQueueCount(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _, player in queue.players do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function compactQueue(modeId)
	local queue = queues[modeId]
	local alive = {}
	for _, player in queue.players do
		if player.Parent and playerQueue[player] == modeId then
			table.insert(alive, player)
		end
	end
	queue.players = alive
end

local function getPlayerNames(modeId)
	compactQueue(modeId)
	local names = {}
	for _, player in queues[modeId].players do
		table.insert(names, player.Name)
	end
	return names
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return nil
	end

	compactQueue(modeId)
	local count = #queue.players
	local status = "waiting"
	if MatchStateService.isBusy() and count >= mode.minPlayers then
		status = "pending"
	elseif modeId == "ffa" and queue.fillEndsAt and count >= mode.minPlayers then
		status = "starting"
	end

	local fillSecondsLeft
	if queue.fillEndsAt then
		fillSecondsLeft = math.max(0, math.ceil(queue.fillEndsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		desc = mode.desc,
		count = count,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		players = getPlayerNames(modeId),
		status = status,
		fillSecondsLeft = fillSecondsLeft,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	compactQueue(modeId)
	for _, player in queues[modeId].players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			break
		end
	end

	if getQueueCount(modeId) < MatchModes.get(modeId).minPlayers then
		queue.fillEndsAt = nil
		ffaFillTokens[modeId] += 1
	end

	broadcastQueueUpdate(modeId)
end

local function popPlayersForMatch(modeId, count)
	compactQueue(modeId)
	local picked = {}
	local queue = queues[modeId]
	for i = 1, math.min(count, #queue.players) do
		local player = queue.players[1]
		table.remove(queue.players, 1)
		playerQueue[player] = nil
		table.insert(picked, player)
	end
	queue.pending = false
	queue.fillEndsAt = nil
	ffaFillTokens[modeId] += 1
	return picked
end

local function launchMatch(playerList)
	if #playerList == 0 then
		return
	end

	for _, player in playerList do
		if player.Parent and HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
		end
	end

	MatchReadyBindable:Fire(playerList)
end

local function tryStartMatch(modeId, forceStart)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return
	end

	compactQueue(modeId)
	local count = getQueueCount(modeId)

	if count < mode.minPlayers then
		queue.pending = false
		broadcastQueueUpdate(modeId)
		return
	end

	if MatchStateService.isBusy() then
		queue.pending = true
		broadcastQueueUpdate(modeId)
		return
	end

	if count >= mode.maxPlayers then
		local players = popPlayersForMatch(modeId, mode.maxPlayers)
		broadcastQueueUpdate(modeId)
		launchMatch(players)
		return
	end

	if modeId == "ffa" and not forceStart then
		if not queue.fillEndsAt then
			queue.fillEndsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			ffaFillTokens[modeId] += 1
			local token = ffaFillTokens[modeId]
			broadcastQueueUpdate(modeId)
			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if ffaFillTokens[modeId] ~= token then
					return
				end
				local q = queues[modeId]
				if not q then
					return
				end
				q.fillEndsAt = nil
				tryStartMatch(modeId, true)
			end)
		end
		return
	end

	local players = popPlayersForMatch(modeId, count)
	broadcastQueueUpdate(modeId)
	launchMatch(players)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end
	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId].players, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFree()
	for modeId, queue in queues do
		if queue.pending or getQueueCount(modeId) >= MatchModes.get(modeId).minPlayers then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.start()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			for modeId, queue in queues do
				if queue.fillEndsAt or queue.pending or #queue.players > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

function MatchmakingService._bind(remotes, bindables)
	Remotes = remotes
	MatchReadyBindable = bindables.MatchReady
end

return MatchmakingService
