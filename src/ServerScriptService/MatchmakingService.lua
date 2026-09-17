local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local ffaFillDeadline = nil
local started = false

local function queueCount(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local count = queueCount(entry.modeId)
	local status = entry.status or "waiting"

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		playerCount = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeLeft = nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payloadByPlayer = {}
	for _, player in queues[modeId] do
		payloadByPlayer[player] = buildQueuePayload(player)
	end

	for player, payload in payloadByPlayer do
		if player.Parent then
			if modeId == "ffa" and ffaFillDeadline and payload.status == "waiting" then
				payload.fillTimeLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
			end
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.getAll() do
		broadcastQueueUpdate(mode.id)
	end
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if modeId == "ffa" and queueCount("ffa") < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
		ffaFillDeadline = nil
	end

	broadcastQueueUpdate(modeId)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
		end
	end
	return picked
end

local function markPending(players, modeId)
	for _, player in players do
		local entry = playerQueue[player]
		if entry then
			entry.status = "pending"
		end
	end
	broadcastQueueUpdate(modeId)
end

local function startMatch(players, modeId)
	for _, player in players do
		removeFromQueue(player)
		if HubService.getPhase(player) ~= "arena" then
			HubService.enterArena(player)
		end
	end

	ffaFillToken += 1
	ffaFillDeadline = nil
	broadcastAllQueues()

	MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		local pending = {}
		for _, player in queues[modeId] do
			table.insert(pending, player)
		end
		markPending(pending, modeId)
		return
	end

	local take = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, take)
	if #players >= mode.minPlayers then
		startMatch(players, modeId)
	end
end

local function scheduleFfaFill()
	local mode = MatchModes.ffa
	if queueCount("ffa") < mode.minPlayers then
		ffaFillDeadline = nil
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	broadcastQueueUpdate("ffa")

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		ffaFillDeadline = nil
		tryStartMode("ffa")
	end)
end

local function onQueueChanged(modeId)
	broadcastQueueUpdate(modeId)

	local mode = MatchModes.get(modeId)
	local count = queueCount(modeId)

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			ffaFillToken += 1
			ffaFillDeadline = nil
			tryStartMode("ffa")
		elseif count >= mode.minPlayers and not ffaFillDeadline then
			scheduleFfaFill()
		elseif count < mode.minPlayers then
			ffaFillToken += 1
			ffaFillDeadline = nil
			broadcastQueueUpdate("ffa")
		end
		return
	end

	if count >= mode.minPlayers then
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return false
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		status = "waiting",
		joinedAt = os.clock(),
	}

	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.joinSmartQueue(player)
	local count = #Players:GetPlayers()
	local modeId = MatchmakingConfig.DEFAULT_MODE
	if count >= 3 then
		modeId = "ffa"
	elseif count == 2 then
		modeId = "pvp"
	else
		modeId = "training"
	end
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "smart" then
			MatchmakingService.joinSmartQueue(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if MatchStateService.isArenaBusy() then
				continue
			end

			for _, mode in MatchModes.getAll() do
				local hasPending = false
				for _, queued in queues[mode.id] do
					local entry = playerQueue[queued]
					if entry and entry.status == "pending" and queueCount(mode.id) >= mode.minPlayers then
						hasPending = true
						break
					end
				end
				if hasPending then
					tryStartMode(mode.id)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
