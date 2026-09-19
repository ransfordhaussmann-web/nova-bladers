local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local fillTimers = {}
local starting = false

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function queuePlayerList(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	return modeId
end

local function buildPayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local members = queuePlayerList(modeId)
	local roster = {}
	for _, member in members do
		table.insert(roster, {
			name = member.Name,
			userId = member.UserId,
		})
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif mode.instantStart and #members >= mode.minPlayers then
		status = "starting"
	elseif #members >= mode.maxPlayers then
		status = "starting"
	elseif modeId == "pvp" and #members >= mode.minPlayers then
		status = "starting"
	elseif modeId == "ffa" and fillTimers[modeId] then
		status = "filling"
	end

	local fillTimeLeft = nil
	if fillTimers[modeId] and fillTimers[modeId].endsAt then
		fillTimeLeft = math.max(0, math.ceil(fillTimers[modeId].endsAt - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		players = roster,
		count = #members,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeLeft = fillTimeLeft,
		inQueue = player ~= nil and playerQueue[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	local payload = buildPayload(modeId)
	if not payload then
		return
	end

	for _, player in queuePlayerList(modeId) do
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function clearQueue(modeId, takeCount)
	local taken = {}
	local queue = queues[modeId]
	while #taken < takeCount and #queue > 0 do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end

	return taken
end

local function startMatch(modeId)
	if MatchStateService.isBusy() or starting then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local members = queuePlayerList(modeId)
	if #members < mode.minPlayers then
		return false
	end

	starting = true

	local takeCount = math.min(#members, mode.maxPlayers)
	local players = clearQueue(modeId, takeCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		starting = false
		return false
	end

	for _, player in players do
		HubService.enterArena(player)
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			modeLabel = mode.label,
			status = "starting",
			players = {},
			count = 0,
			minPlayers = mode.minPlayers,
			maxPlayers = mode.maxPlayers,
			inQueue = false,
		})
	end

	Bindables.MatchReady:Fire(players, modeId)
	starting = false
	return true
end

local function maybeStartFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or modeId ~= "ffa" then
		return
	end

	local members = queuePlayerList(modeId)
	if #members < mode.minPlayers or #members >= mode.maxPlayers then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = { cancelled = false }
	fillTimers[modeId] = token
	token.endsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT

	task.spawn(function()
		local deadline = token.endsAt
		while not token.cancelled and os.clock() < deadline do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueue(modeId)
		end

		if token.cancelled then
			return
		end

		fillTimers[modeId] = nil
		if not MatchStateService.isBusy() then
			startMatch(modeId)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local members = queuePlayerList(modeId)
	if #members == 0 then
		if fillTimers[modeId] then
			fillTimers[modeId].cancelled = true
			fillTimers[modeId] = nil
		end
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	if mode.instantStart and #members >= mode.minPlayers then
		startMatch(modeId)
		return
	end

	if #members >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if modeId == "pvp" and #members >= mode.minPlayers then
		startMatch(modeId)
		return
	end

	if modeId == "ffa" then
		if #members >= mode.minPlayers then
			maybeStartFillTimer(modeId)
		else
			if fillTimers[modeId] then
				fillTimers[modeId].cancelled = true
				fillTimers[modeId] = nil
			end
		end
	end

	broadcastQueue(modeId)
end

local function evaluateAllQueues()
	for modeId in queues do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end

	modeId = modeId or getRecommendedModeId()
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	local previousMode = removePlayerFromQueue(player)
	if previousMode and previousMode ~= modeId then
		broadcastQueue(previousMode)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	evaluateQueue(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = removePlayerFromQueue(player)
	if modeId then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "left",
			inQueue = false,
		})
		evaluateQueue(modeId)
	end
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.init()
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
		local modeId = removePlayerFromQueue(player)
		if modeId then
			task.defer(function()
				evaluateQueue(modeId)
			end)
		end
	end)

	MatchStateService.onArenaFree(function()
		evaluateAllQueues()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
