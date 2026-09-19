local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerQueue = {}
local pendingPlayers = {}
local fillDeadline = {}
local fillTokens = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueueList(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end
end

local function clearPlayerQueue(player)
	local modeId = playerQueue[player]
	if modeId then
		removeFromQueueList(player, modeId)
		playerQueue[player] = nil
	end
	pendingPlayers[player] = nil
end

local function buildQueuePayload(modeId, status, extra)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local payload = {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		min = mode.minPlayers,
		max = mode.maxPlayers,
	}
	if extra then
		for key, value in extra do
			payload[key] = value
		end
	end
	if fillDeadline[modeId] then
		payload.fillSecondsLeft = math.max(0, math.ceil(fillDeadline[modeId] - os.clock()))
	end
	return payload
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueueMode(modeId, status)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		sendQueueUpdate(player, buildQueuePayload(modeId, status))
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillDeadline[modeId] = nil
end

local function tryLaunchMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" and #queue < mode.maxPlayers then
		if not fillDeadline[modeId] then
			return
		end
		if os.clock() < fillDeadline[modeId] then
			return
		end
	end

	local playerList = {}
	for index = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(playerList, queue[index])
	end

	for _, player in playerList do
		clearPlayerQueue(player)
	end
	cancelFillTimer(modeId)
	broadcastQueueMode(modeId, "starting")

	MatchStateService.setArenaBusy(true)
	for _, player in playerList do
		if HubService.getPhase(player) == "hub" then
			HubService.leaveHubForMatch(player)
		end
	end
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function scheduleFillTimer(modeId)
	if modeId ~= "ffa" then
		return
	end

	local mode = MatchModes.get(modeId)

	local token = (fillTokens[modeId] or 0) + 1
	fillTokens[modeId] = token
	fillDeadline[modeId] = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	broadcastQueueMode(modeId, "waiting")

	task.spawn(function()
		while token == fillTokens[modeId] do
			local queue = ensureQueue(modeId)
			if #queue < mode.minPlayers then
				cancelFillTimer(modeId)
				return
			end
			if #queue >= mode.maxPlayers then
				tryLaunchMatch(modeId)
				return
			end
			if os.clock() >= fillDeadline[modeId] then
				tryLaunchMatch(modeId)
				return
			end
			broadcastQueueMode(modeId, "waiting")
			task.wait(1)
		end
	end)
end

local function evaluateMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		cancelFillTimer(modeId)
		return
	end

	if modeId == "pvp" or modeId == "training" then
		if #queue >= mode.maxPlayers then
			tryLaunchMatch(modeId)
		end
		return
	end

	if #queue >= mode.maxPlayers then
		tryLaunchMatch(modeId)
		return
	end

	if not fillDeadline[modeId] then
		scheduleFillTimer(modeId)
	else
		broadcastQueueMode(modeId, "waiting")
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] and not pendingPlayers[player] then
		sendQueueUpdate(player, { status = "idle" })
		return
	end

	local modeId = playerQueue[player] or pendingPlayers[player]
	clearPlayerQueue(player)
	if modeId then
		cancelFillTimer(modeId)
		evaluateMode(modeId)
		broadcastQueueMode(modeId, "waiting")
	end
	sendQueueUpdate(player, { status = "idle" })
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end
	if playerQueue[player] == modeId or pendingPlayers[player] == modeId then
		return
	end

	MatchmakingService.leaveQueue(player)

	if MatchStateService.isArenaBusy() then
		pendingPlayers[player] = modeId
		sendQueueUpdate(player, buildQueuePayload(modeId, "pending", {
			reason = "Arena belegt — du startest als Nächstes",
		}))
		return
	end

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId
	sendQueueUpdate(player, buildQueuePayload(modeId, "waiting"))
	broadcastQueueMode(modeId, "waiting")
	evaluateMode(modeId)
end

local function processPending()
	local pending = {}
	for player, modeId in pendingPlayers do
		table.insert(pending, { player = player, modeId = modeId })
	end
	for _, entry in pending do
		if entry.player.Parent then
			pendingPlayers[entry.player] = nil
			MatchmakingService.joinQueue(entry.player, entry.modeId)
		else
			pendingPlayers[entry.player] = nil
		end
	end
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	processPending()
	for _, modeId in { "training", "pvp", "ffa" } do
		evaluateMode(modeId)
	end
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.DEFAULT_MODE
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
