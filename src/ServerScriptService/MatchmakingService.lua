local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local handlers = {}
local Remotes
local MatchReady
local MatchEnded

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local fillTimers = {}

local function queueIndex(modeId, player)
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local idx = queueIndex(entry.modeId, player)
	if idx then
		table.remove(queues[entry.modeId], idx)
	end
	playerEntry[player] = nil
end

local function getStatus(modeId)
	if MatchStateService.isBusy() then
		return "pending"
	end
	local mode = MatchModes.get(modeId)
	local count = #queues[modeId]
	if count >= mode.maxPlayers then
		return "ready"
	end
	if count >= mode.minPlayers and not mode.useFillTimeout then
		return "ready"
	end
	return "waiting"
end

local function buildPayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local count = #queues[modeId]
	local entry = playerEntry[player]
	local fillTimeLeft

	if entry and entry.fillDeadline then
		fillTimeLeft = math.max(0, math.ceil(entry.fillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = entry and entry.status or getStatus(modeId),
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = queueIndex(modeId, player),
		fillTimeLeft = fillTimeLeft,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function pushUpdate(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end
	entry.status = getStatus(entry.modeId)
	Remotes.QueueUpdate:FireClient(player, buildPayload(entry.modeId, player))
end

local function broadcastMode(modeId)
	for _, player in queues[modeId] do
		pushUpdate(player)
	end
end

local function cancelFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.spawn(function()
		local deadline = os.clock() + MatchmakingConfig.FILL_TIMEOUT_SEC
		for _, player in queues[modeId] do
			local entry = playerEntry[player]
			if entry then
				entry.fillDeadline = deadline
			end
		end
		broadcastMode(modeId)

		while fillTimers[modeId] == token do
			local remaining = deadline - os.clock()
			if remaining <= 0 then
				break
			end
			task.wait(MatchmakingConfig.QUEUE_TICK_SEC)
			broadcastMode(modeId)
		end

		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatches()
	end)
end

local function clearFillDeadlines(modeId)
	for _, player in queues[modeId] do
		local entry = playerEntry[player]
		if entry then
			entry.fillDeadline = nil
		end
	end
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	if mode.useFillTimeout and #queues[modeId] < mode.minPlayers then
		cancelFillTimer(modeId)
		clearFillDeadlines(modeId)
	end

	broadcastMode(modeId)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = getStatus(modeId),
	}

	local mode = MatchModes.get(modeId)
	if mode.useFillTimeout and #queues[modeId] >= mode.minPlayers then
		startFillTimer(modeId)
	end

	pushUpdate(player)
	broadcastMode(modeId)
	MatchmakingService.tryStartMatches()
end

function MatchmakingService.tryStartMatches()
	if MatchStateService.isBusy() then
		for modeId, _ in pairs(queues) do
			broadcastMode(modeId)
		end
		return
	end

	for _, modeId in MatchmakingConfig.MODE_PRIORITY do
		local mode = MatchModes.get(modeId)
		local queue = queues[modeId]
		local count = #queue

		if count >= mode.minPlayers
			and not (mode.useFillTimeout and count < mode.maxPlayers and fillTimers[modeId])
		then
		local roster = {}
		local take = math.min(count, mode.maxPlayers)
		for i = 1, take do
			table.insert(roster, queue[i])
		end

		cancelFillTimer(modeId)
		clearFillDeadlines(modeId)

		for _, p in roster do
			removeFromQueue(p)
		end

		MatchStateService.setBusy(true)
		for _, p in roster do
			Remotes.QueueUpdate:FireClient(p, { status = "starting", modeId = modeId, modeLabel = mode.label })
		end

		if handlers.onMatchReady then
			handlers.onMatchReady(roster, modeId)
		end
		MatchReady:Fire(roster, modeId)
		return
		end
	end
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(function()
		MatchmakingService.tryStartMatches()
	end)
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
		if handlers.onJoinQueue then
			handlers.onJoinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_SEC)
			for modeId, _ in pairs(queues) do
				if #queues[modeId] > 0 then
					broadcastMode(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
