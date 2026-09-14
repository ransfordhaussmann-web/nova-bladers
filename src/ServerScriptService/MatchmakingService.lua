local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local fillTokens = {}
local started = false

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidMode(modeId)
	return getMode(modeId) ~= nil
end

local function queueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if queueSize(entry.modeId) == 0 then
		fillTimers[entry.modeId] = nil
		fillTokens[entry.modeId] = (fillTokens[entry.modeId] or 0) + 1
	end
end

local function getQuickModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return nil
	end

	local mode = getMode(entry.modeId)
	local size = queueSize(entry.modeId)
	local pending = GameMatchState.isArenaBusy()
	local fillSeconds

	if mode.fillTimeout and fillTimers[entry.modeId] then
		fillSeconds = math.max(0, math.ceil(fillTimers[entry.modeId] - os.clock()))
	end

	local status = "waiting"
	if pending then
		status = "pending"
	elseif size >= mode.minPlayers then
		status = "ready"
	end

	return {
		status = status,
		modeId = mode.id,
		modeLabel = mode.label,
		queueSize = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSeconds = fillSeconds,
		pending = pending,
	}
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			local payload = buildQueuePayload(player)
			if payload then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function takePlayersForMatch(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(matchPlayers, nextPlayer)
			playerQueue[nextPlayer] = nil
		end
	end

	fillTimers[modeId] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1

	return matchPlayers
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	if queueSize(modeId) < mode.minPlayers then
		return
	end

	if GameMatchState.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local matchPlayers = takePlayersForMatch(modeId)
	if #matchPlayers < mode.minPlayers then
		for _, matchPlayer in matchPlayers do
			MatchmakingService.joinQueue(matchPlayer, modeId)
		end
		return
	end

	GameMatchState.setArenaBusy(true)
	for _, matchPlayer in matchPlayers do
		HubService.leaveHubForArena(matchPlayer)
		Remotes.QueueUpdate:FireClient(matchPlayer, {
			status = "starting",
			modeId = mode.id,
			modeLabel = mode.label,
		})
	end

	broadcastAllQueues()
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillTimers[modeId] = os.clock() + mode.fillTimeout
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
		if queueSize(modeId) > 0 and queueSize(modeId) < mode.minPlayers then
			scheduleFillTimer(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end
	if not isValidMode(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	local mode = getMode(modeId)
	if mode.fillTimeout and queueSize(modeId) == 1 then
		scheduleFillTimer(modeId)
	elseif queueSize(modeId) >= mode.minPlayers then
		tryStartMatch(modeId)
	else
		broadcastQueue(modeId)
	end

	return true
end

function MatchmakingService.joinQuickMatch(player)
	return MatchmakingService.joinQueue(player, getQuickModeId())
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueue(modeId)
	return true
end

function MatchmakingService.onArenaFree()
	broadcastAllQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getQuickModeId()
	return getQuickModeId()
end

function MatchmakingService.start(hub)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if hub then
		hub.portalPrompt.Triggered:Connect(function(player)
			MatchmakingService.joinQuickMatch(player)
		end)

		for _, pad in hub.modePads do
			if pad.prompt then
				pad.prompt.Triggered:Connect(function(player)
					MatchmakingService.joinQueue(player, pad.config.id)
				end)
			end
		end
	end

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastAllQueues()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
