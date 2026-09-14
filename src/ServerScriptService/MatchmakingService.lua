local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady
local ArenaFree

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaTimerStart = nil
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function modeLabel(modeId)
	local mode = MatchModes.get(modeId)
	return mode and mode.label or modeId
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

	if entry.modeId == "ffa" and #queue == 0 then
		ffaTimerStart = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local entry = playerQueue[player]
	local status = "waiting"
	if GameMatchState.isArenaBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = #queue,
		requiredPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		joinedAt = entry and entry.joinedAt or os.clock(),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent and playerQueue[queuedPlayer] then
			local payload = buildQueuePayload(queuedPlayer, modeId)
			if payload then
				Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if mode.instant then
		return true
	end

	if modeId == "ffa" and ffaTimerStart then
		local elapsed = os.clock() - ffaTimerStart
		if elapsed >= (mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT) and count >= mode.minPlayers then
			return true
		end
	end

	if modeId == "pvp" and count >= mode.minPlayers then
		return true
	end

	return false
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(matchPlayers, player)
			playerQueue[player] = nil
		end
	end

	if modeId == "ffa" and #queue == 0 then
		ffaTimerStart = nil
	end

	return matchPlayers
end

local function tryStartMatch(modeId)
	if GameMatchState.isArenaBusy() then
		return
	end

	if not canStartMode(modeId) then
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	GameMatchState.setArenaBusy(true)
	MatchReady:Fire(matchPlayers, modeId)
	broadcastAllQueues()
end

local function tryAllQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
		if GameMatchState.isArenaBusy() then
			break
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	if modeId == "ffa" and not ffaTimerStart then
		ffaTimerStart = os.clock()
	end

	local payload = buildQueuePayload(player, modeId)
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastQueueUpdate(modeId)

	if GameMatchState.isArenaBusy() then
		return true
	end

	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)
	broadcastAllQueues()
	tryAllQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ArenaFree = Bindables.ArenaFree

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			if not GameMatchState.isArenaBusy() then
				tryAllQueues()
			else
				broadcastAllQueues()
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
