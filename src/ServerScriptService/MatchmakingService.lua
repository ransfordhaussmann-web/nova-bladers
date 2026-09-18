local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillDeadline = {}
local hubApi = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent == Players
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	local count = countValidPlayers(getQueue(modeId))
	if mode and count < mode.minPlayers then
		if fillTimers[modeId] then
			task.cancel(fillTimers[modeId])
			fillTimers[modeId] = nil
		end
		fillDeadline[modeId] = nil
	end
end

local function countValidPlayers(queue)
	local count = 0
	for _, player in queue do
		if isPlayerValid(player) then
			count += 1
		end
	end
	return count
end

local function getValidPlayers(queue, maxCount)
	local result = {}
	for _, player in queue do
		if isPlayerValid(player) and #result < maxCount then
			table.insert(result, player)
		end
	end
	return result
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local count = countValidPlayers(queue)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
	}

	if mode.fillTimeout > 0 and fillDeadline[modeId] then
		payload.secondsLeft = math.max(0, math.ceil(fillDeadline[modeId] - os.clock()))
	end

	return payload
end

local function broadcastQueueUpdate(modeId, status)
	local queue = getQueue(modeId)
	for _, player in queue do
		if isPlayerValid(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
		end
	end
end

local function clearQueueUpdate(player)
	if isPlayerValid(player) then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local count = countValidPlayers(getQueue(modeId))
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if mode.fillTimeout > 0 and fillDeadline[modeId] and os.clock() >= fillDeadline[modeId] then
		return true
	end
	return mode.fillTimeout == 0 and count >= mode.minPlayers
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillDeadline[modeId] = os.clock() + mode.fillTimeout
	fillTimers[modeId] = task.delay(mode.fillTimeout, function()
		fillTimers[modeId] = nil
		MatchmakingService.tryStartMatch(modeId)
	end)

	broadcastQueueUpdate(modeId, "waiting")
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local selected = getValidPlayers(queue, mode.maxPlayers)

	for _, player in selected do
		removeFromQueue(player)
	end

	return selected
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if not canStartMode(modeId) then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId, "pending")
		return
	end

	local players = popPlayersForMatch(modeId)
	if #players < mode.minPlayers then
		return
	end

	for _, player in players do
		clearQueueUpdate(player)
		if hubApi.leaveHubForArena then
			hubApi.leaveHubForArena(player)
		end
	end

	broadcastQueueUpdate(modeId, "starting")
	MatchReady:Fire(modeId, players)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isPlayerValid(player) then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if hubApi.getPhase and hubApi.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	local count = countValidPlayers(queue)
	if mode.fillTimeout > 0 and count >= mode.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	broadcastQueueUpdate(modeId, MatchStateService.isArenaBusy() and "pending" or "waiting")
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		clearQueueUpdate(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	clearQueueUpdate(player)
	broadcastQueueUpdate(modeId, "waiting")
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init(api)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	hubApi = api or {}

	MatchStateService.onArenaFree(function()
		for _, mode in MatchModes.all() do
			if countValidPlayers(getQueue(mode.id)) >= mode.minPlayers then
				MatchmakingService.tryStartMatch(mode.id)
			end
		end
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if hubApi.modePads then
		for _, pad in hubApi.modePads do
			if pad.prompt then
				pad.prompt.Triggered:Connect(function(player)
					MatchmakingService.joinQueue(player, pad.config.id)
				end)
			end
		end
	end

	if hubApi.portalPrompt then
		hubApi.portalPrompt.Triggered:Connect(function(player)
			MatchmakingService.joinQueue(player, MatchmakingService.getRecommendedModeId())
		end)
	end

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
