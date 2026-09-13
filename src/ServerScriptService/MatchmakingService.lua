local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local ArenaFree = Bindables.ArenaFree

local queues = {}
local playerQueue = {}
local fillDeadlines = {}
local onMatchReady
local tickConnection

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildQueuePayload(modeId, player)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local position = 0
	for i, p in queue do
		if p == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if GameMatchState.isArenaBusy() then
		status = "pending"
	elseif mode.fillTimeout > 0 and #queue >= mode.minPlayers and fillDeadlines[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status,
		fillSecondsLeft = nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			local payload = buildQueuePayload(modeId, player)
			if fillDeadlines[modeId] and payload.status == "filling" then
				payload.fillSecondsLeft = math.max(0, math.ceil(fillDeadlines[modeId] - os.clock()))
			end
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue < getMode(modeId).minPlayers then
		fillDeadlines[modeId] = nil
	end

	broadcastQueueUpdate(modeId)
end

local function pullPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local pulled = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(pulled, player)
		end
	end
	fillDeadlines[modeId] = nil
	return pulled
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	GameMatchState.setArenaBusy(true)
	for _, player in players do
		if onMatchReady then
			onMatchReady(player, modeId)
		end
	end
	MatchReady:Fire(modeId, players)
end

local function tryStartMode(modeId)
	if GameMatchState.isArenaBusy() then
		return
	end

	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if mode.maxPlayers == mode.minPlayers and #queue >= mode.minPlayers then
		local players = pullPlayers(modeId, mode.maxPlayers)
		launchMatch(modeId, players)
		broadcastQueueUpdate(modeId)
		return
	end

	if mode.fillTimeout > 0 then
		if not fillDeadlines[modeId] then
			fillDeadlines[modeId] = os.clock() + mode.fillTimeout
			broadcastQueueUpdate(modeId)
			return
		end

		if os.clock() >= fillDeadlines[modeId] or #queue >= mode.maxPlayers then
			if #queue < mode.minPlayers then
				fillDeadlines[modeId] = nil
				broadcastQueueUpdate(modeId)
				return
			end
			local players = pullPlayers(modeId, math.min(#queue, mode.maxPlayers))
			launchMatch(modeId, players)
			broadcastQueueUpdate(modeId)
		end
		return
	end

	local players = pullPlayers(modeId, mode.maxPlayers)
	launchMatch(modeId, players)
	broadcastQueueUpdate(modeId)
end

local function tryStartAll()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

local function joinQueue(player, modeId)
	if not getMode(modeId) then
		modeId = getRecommendedModeId()
	end

	if playerQueue[player] == modeId then
		broadcastQueueUpdate(modeId)
		return
	end

	removeFromQueue(player)
	table.insert(ensureQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.start(handlers)
	onMatchReady = handlers and handlers.onMatchReady

	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "auto" then
			modeId = getRecommendedModeId()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	end)

	ArenaFree.Event:Connect(function()
		GameMatchState.setArenaBusy(false)
		task.defer(tryStartAll)
	end)

	if tickConnection then
		tickConnection:Disconnect()
	end
	tickConnection = task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.FILL_TICK)
			for modeId, deadline in fillDeadlines do
				if deadline and os.clock() >= deadline then
					tryStartMode(modeId)
				else
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

return MatchmakingService
