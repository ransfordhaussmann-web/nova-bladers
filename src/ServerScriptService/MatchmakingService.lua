local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(ReplicatedStorage.NovaBladers.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady
local MatchEnded

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}
local fillRunning = {}
local startTokens = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function playerInList(list, player)
	for i, p in list do
		if p == player then
			return i
		end
	end
	return nil
end

local function getPlayerNames(list)
	local names = {}
	for _, p in list do
		if p.Parent then
			table.insert(names, p.Name)
		end
	end
	return names
end

local function buildQueuePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode then
		return nil
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isBusy(),
		playerNames = getPlayerNames(queue),
	}
end

local function sendQueueUpdate(player, payload)
	if player.Parent and payload then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId, status)
	local payload = buildQueuePayload(modeId, status)
	if not payload then
		return
	end
	for _, player in getQueue(modeId) do
		sendQueueUpdate(player, payload)
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local idx = playerInList(getQueue(modeId), player)
	if idx then
		table.remove(getQueue(modeId), idx)
	end
	playerQueue[player] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	startTokens[modeId] = (startTokens[modeId] or 0) + 1
	broadcastQueue(modeId, "waiting")
end

local function cancelFillTimer(modeId)
	fillRunning[modeId] = false
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or #queue < mode.minPlayers then
		return
	end
	if MatchStateService.isBusy() then
		broadcastQueue(modeId, "pending_arena")
		return
	end

	if modeId == "ffa" and #queue < mode.maxPlayers then
		return
	end

	startTokens[modeId] = (startTokens[modeId] or 0) + 1
	local token = startTokens[modeId]

	broadcastQueue(modeId, "starting")

	task.delay(MatchmakingConfig.START_DELAY, function()
		if token ~= startTokens[modeId] then
			return
		end
		if MatchStateService.isBusy() then
			broadcastQueue(modeId, "pending_arena")
			return
		end

		local currentQueue = getQueue(modeId)
		if #currentQueue < mode.minPlayers then
			broadcastQueue(modeId, "waiting")
			return
		end

		local matchPlayers = {}
		local count = math.min(#currentQueue, mode.maxPlayers)
		for i = 1, count do
			table.insert(matchPlayers, currentQueue[i])
		end

		for _, player in matchPlayers do
			clearPlayerFromQueues(player)
			sendQueueUpdate(player, { status = "matched", modeId = modeId })
		end

		MatchReady:Fire(matchPlayers, modeId)
	end)
end

local function scheduleFillTimer(modeId)
	if fillRunning[modeId] then
		return
	end
	fillRunning[modeId] = true
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillRunning[modeId] = false
		if token ~= fillTokens[modeId] then
			return
		end
		local queue = getQueue(modeId)
		local mode = MatchModes.get(modeId)
		if mode and #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId, "pending_arena")
		return
	end

	if #queue >= mode.maxPlayers then
		cancelFillTimer(modeId)
		tryStartMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if modeId == "ffa" then
			broadcastQueue(modeId, "filling")
			scheduleFillTimer(modeId)
		else
			tryStartMatch(modeId)
		end
	else
		broadcastQueue(modeId, "waiting")
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false
	end
	if MatchStateService.isBusy() and not playerQueue[player] then
		-- allow joining; status will show pending_arena
	end

	clearPlayerFromQueues(player)

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	clearPlayerFromQueues(player)
	sendQueueUpdate(player, { status = "left" })
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.resolveQuickMode()
	local pvpCount = #getQueue("pvp")
	if pvpCount >= 1 then
		return "pvp"
	end
	local ffaCount = #getQueue("ffa")
	if ffaCount >= 1 then
		return "ffa"
	end
	local playerCount = #Players:GetPlayers()
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(function()
		for modeId in queues do
			onQueueChanged(modeId)
		end
	end)
end

function MatchmakingService.init(hubCallbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		if modeId == "quick" then
			modeId = MatchmakingService.resolveQuickMode()
		end
		MatchmakingService.joinQueue(player, modeId)
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

	if hubCallbacks then
		MatchmakingService._hubCallbacks = hubCallbacks
	end

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
