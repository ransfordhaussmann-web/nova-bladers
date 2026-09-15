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
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

-- modeId -> { players = {Player}, fillToken = number, fillStartedAt = number? }
local queues = {}
local playerQueue = {} -- Player -> modeId
local started = false

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = { players = {}, fillToken = 0 }
	end
	return queues[modeId]
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players
	local pending = MatchStateService.isArenaBusy()
	local status = "waiting"

	if count >= mode.minPlayers then
		status = pending and "pending" or "ready"
	end

	return {
		modeId = modeId,
		label = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		pending = pending,
	}
end

local function broadcastQueueUpdate(targetPlayer)
	local payload = {
		inQueue = false,
		modeId = nil,
		queues = {},
	}

	for _, mode in MatchModes.all() do
		payload.queues[mode.id] = getQueueStatus(mode.id)
	end

	if targetPlayer then
		local modeId = playerQueue[targetPlayer]
		if modeId then
			payload.inQueue = true
			payload.modeId = modeId
			payload.queue = getQueueStatus(modeId)
		end
		if targetPlayer.Parent then
			Remotes.QueueUpdate:FireClient(targetPlayer, payload)
		end
	else
		for _, player in Players:GetPlayers() do
			local modeId = playerQueue[player]
			local playerPayload = table.clone(payload)
			if modeId then
				playerPayload.inQueue = true
				playerPayload.modeId = modeId
				playerPayload.queue = getQueueStatus(modeId)
			end
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, playerPayload)
			end
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, p in queue.players do
		if p == player then
			table.remove(queue.players, i)
			break
		end
	end
	playerQueue[player] = nil

	-- Cancel fill timer if queue dropped below minimum
	local mode = MatchModes.get(modeId)
	if #queue.players < mode.minPlayers then
		queue.fillToken += 1
		queue.fillStartedAt = nil
	end

	broadcastQueueUpdate()
end

local function popPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local picked = {}
	for i = 1, math.min(count, #queue.players) do
		local player = queue.players[1]
		table.remove(queue.players, 1)
		playerQueue[player] = nil
		table.insert(picked, player)
	end
	queue.fillToken += 1
	queue.fillStartedAt = nil
	broadcastQueueUpdate()
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(modeId, playerList)
	broadcastQueueUpdate()
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players

	if count < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		-- Start fill timer once minimum is reached
		if not queue.fillStartedAt then
			queue.fillStartedAt = os.clock()
			queue.fillToken += 1
			local token = queue.fillToken

			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if token ~= queue.fillToken then
					return
				end
				if MatchStateService.isArenaBusy() then
					return
				end
				local q = ensureQueue(modeId)
				if #q.players < mode.minPlayers then
					return
				end
				local take = math.min(#q.players, mode.maxPlayers)
				local players = popPlayers(modeId, take)
				launchMatch(modeId, players)
			end)
		end

		-- Immediate start if queue is full
		if count >= mode.maxPlayers then
			queue.fillToken += 1
			local players = popPlayers(modeId, mode.maxPlayers)
			launchMatch(modeId, players)
		end
		return
	end

	-- Training / PvP: start as soon as minimum is met
	local take = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, take)
	launchMatch(modeId, players)
end

local function joinQueue(player, modeId)
	if playerQueue[player] then
		return false, "already_queued"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	local queue = ensureQueue(modeId)
	if #queue.players >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue.players, player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(player)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.join(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leave(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.joinAuto(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.resolveFromPlayerCount(count)
	return joinQueue(player, mode.id)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	broadcastQueueUpdate()

	-- Retry pending queues
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastQueueUpdate()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
