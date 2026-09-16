local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local HubService
local queues = {}
local playerQueue = {}
local fillTimers = {}
local pendingMatch = nil
local started = false

local function getModeFromServerCount()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if modeId and MatchModes.get(modeId) then
		return modeId
	end
	return getModeFromServerCount()
end

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

	if fillTimers[entry.modeId] then
		local mode = MatchModes.get(entry.modeId)
		local queue = getQueue(entry.modeId)
		if #queue < mode.minPlayers then
			fillTimers[entry.modeId] = nil
		end
	end
end

local function buildQueuePayload(player, modeId, status, pendingReason)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queuedCount = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
		pendingReason = pendingReason,
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueUpdates(modeId, status, pendingReason)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		sendQueueUpdate(queuedPlayer, buildQueuePayload(queuedPlayer, modeId, status, pendingReason))
	end
end

local function clearQueueLeave(player)
	removeFromQueue(player)
	sendQueueUpdate(player, { inQueue = false })
end

local function tryStartMatch(modeId)
	if pendingMatch then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue < mode.minPlayers then
		return false
	end

	if #queue > mode.maxPlayers then
		while #queue > mode.maxPlayers do
			local overflow = table.remove(queue)
			playerQueue[overflow] = nil
			sendQueueUpdate(overflow, { inQueue = false })
		end
	end

	local roster = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(roster, queue[i])
	end

	if MatchStateService.isBusy() then
		pendingMatch = { modeId = modeId, players = roster }
		broadcastQueueUpdates(modeId, "pending", "Arena belegt — warte...")
		return false
	end

	for _, player in roster do
		removeFromQueue(player)
		if HubService and HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end

	fillTimers[modeId] = nil
	Bindables.MatchReady:Fire(roster, modeId)
	return true
end

local function onFillTimeout(modeId, token)
	if fillTimers[modeId] ~= token then
		return
	end
	fillTimers[modeId] = nil
	tryStartMatch(modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token
	task.delay(mode.fillTimeout, function()
		onFillTimeout(modeId, token)
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	broadcastQueueUpdates(modeId, "waiting")

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		scheduleFillTimeout(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if playerQueue[player] then
		return
	end

	modeId = resolveModeId(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		sendQueueUpdate(player, {
			inQueue = false,
			error = "Warteschlange voll",
		})
		return
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }
	sendQueueUpdate(player, buildQueuePayload(player, modeId, "waiting"))
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player].modeId
	clearQueueLeave(player)
	onQueueChanged(modeId)
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

local function processPendingMatch()
	if not pendingMatch or MatchStateService.isBusy() then
		return
	end

	local roster = pendingMatch.players
	local modeId = pendingMatch.modeId
	pendingMatch = nil

	for _, player in roster do
		if player.Parent and playerQueue[player] then
			removeFromQueue(player)
			if HubService and HubService.leaveHubForArena then
				HubService.leaveHubForArena(player)
			end
		end
	end

	Bindables.MatchReady:Fire(roster, modeId)
end

function MatchmakingService.start(hubServiceRef)
	if started then
		return
	end
	started = true
	HubService = hubServiceRef

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = nil
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if pendingMatch then
			for i, rosterPlayer in pendingMatch.players do
				if rosterPlayer == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			local mode = MatchModes.get(pendingMatch.modeId)
			if #pendingMatch.players < mode.minPlayers then
				pendingMatch = nil
			end
		end
	end)

	MatchStateService.onArenaIdle(function()
		processPendingMatch()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId, mode in pairs(MatchModes) do
				if typeof(mode) == "table" and mode.id then
					local queue = getQueue(modeId)
					if #queue > 0 then
						local isPending = pendingMatch and pendingMatch.modeId == modeId
						broadcastQueueUpdates(
							modeId,
							isPending and "pending" or "waiting",
							isPending and "Arena belegt — warte..." or nil
						)
					end
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
