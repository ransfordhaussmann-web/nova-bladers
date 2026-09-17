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

local queues = {}
local playerQueue = {}
local fillTimers = {}
local starting = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
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
	if fillTimers[entry.modeId] and #queue < (MatchModes.get(entry.modeId).preferredPlayers or MatchModes.get(entry.modeId).minPlayers) then
		fillTimers[entry.modeId] = nil
	end
end

local function getStatus(modeId, queueSize)
	if MatchStateService.isBusy() then
		return "pending"
	end
	if starting then
		return "starting"
	end

	local mode = MatchModes.get(modeId)
	if mode.id == "ffa" and queueSize >= (mode.preferredPlayers or mode.minPlayers) then
		return "ready"
	end
	if queueSize >= mode.maxPlayers then
		return "ready"
	end
	if mode.id == "ffa" and queueSize >= mode.minPlayers and fillTimers[modeId] then
		return "filling"
	end
	return "waiting"
end

local function getSecondsLeft(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout or not fillTimers[modeId] then
		return nil
	end
	return math.max(0, math.ceil(fillTimers[modeId] - os.clock()))
end

local function buildUpdate(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getStatus(entry.modeId, #queue),
		secondsLeft = getSecondsLeft(entry.modeId),
	}
end

local function sendUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdate(player))
	end
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		sendUpdate(queuedPlayer)
	end
end

local function shouldStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local size = #queue

	if size < mode.minPlayers then
		return false
	end
	if size >= mode.maxPlayers then
		return true
	end
	if mode.id == "ffa" then
		if size >= (mode.preferredPlayers or mode.minPlayers) then
			return true
		end
		if size >= mode.minPlayers and fillTimers[modeId] and os.clock() >= fillTimers[modeId] then
			return true
		end
		return false
	end
	return size >= mode.maxPlayers
end

local function popPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local players = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(players, player)
			playerQueue[player] = nil
		end
	end

	fillTimers[modeId] = nil
	return players
end

local function tryStartMatch(modeId)
	if starting or MatchStateService.isBusy() then
		return false
	end
	if not shouldStartMode(modeId) then
		return false
	end

	local players = popPlayers(modeId)
	if #players == 0 then
		return false
	end

	starting = true
	for _, player in players do
		sendUpdate(player)
	end

	task.delay(MatchmakingConfig.START_DELAY, function()
		starting = false
		if MatchStateService.isBusy() then
			for _, player in players do
				if player.Parent and HubService.getPhase(player) == "hub" then
					local queue = getQueue(modeId)
					table.insert(queue, player)
					playerQueue[player] = { modeId = modeId }
					sendUpdate(player)
				end
			end
			broadcastQueue(modeId)
			return
		end

		local activePlayers = {}
		for _, player in players do
			if player.Parent and HubService.getPhase(player) == "hub" then
				table.insert(activePlayers, player)
			end
		end

		if #activePlayers == 0 then
			MatchmakingService.processQueues()
			return
		end

		MatchReady:Fire(activePlayers, modeId)
	end)

	return true
end

function MatchmakingService.processQueues()
	for _, mode in MatchModes.getAll() do
		local queue = getQueue(mode.id)
		if #queue > 0 then
			if mode.fillTimeout and #queue >= mode.minPlayers and not fillTimers[mode.id] then
				fillTimers[mode.id] = os.clock() + mode.fillTimeout
				broadcastQueue(mode.id)
			end
			tryStartMatch(mode.id)
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
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	if mode.fillTimeout and #queue >= mode.minPlayers and not fillTimers[modeId] then
		fillTimers[modeId] = os.clock() + mode.fillTimeout
	end

	sendUpdate(player)
	broadcastQueue(modeId)
	MatchmakingService.processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendUpdate(player)
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	sendUpdate(player)
	broadcastQueue(modeId)
end

function MatchmakingService.quickMatch(player)
	local modeId = MatchModes.recommendForPlayerCount(#Players:GetPlayers())
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" then
			MatchmakingService.quickMatch(player)
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

	MatchStateService.onIdle(function()
		task.defer(MatchmakingService.processQueues)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId, deadline in fillTimers do
				local queue = getQueue(modeId)
				if #queue < MatchModes.get(modeId).minPlayers then
					fillTimers[modeId] = nil
				elseif os.clock() >= deadline then
					tryStartMatch(modeId)
				else
					broadcastQueue(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
