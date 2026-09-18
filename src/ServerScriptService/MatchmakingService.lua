--[[
	MatchmakingService — per-mode queues with fill timers and arena-busy pending state.
]]

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

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTokens = {}
local fillEndsAt = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil
	fillEndsAt[modeId] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function addToQueue(player, modeId)
	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId
end

local function queueSize(modeId)
	return #getQueue(modeId)
end

local function getStatus(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local size = queueSize(modeId)
	local position = 0
	for i, queued in getQueue(modeId) do
		if queued == player then
			position = i
			break
		end
	end

	local ready = size >= mode.minPlayers
	if mode.maxPlayers and size >= mode.maxPlayers then
		ready = true
	end

	local status = "waiting"
	if ready then
		status = MatchStateService.isBusy() ? "pending" : "starting"
	end

	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		position = position,
		queueSize = size,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}

	if modeId == "ffa" and fillEndsAt[modeId] and size >= mode.minPlayers then
		payload.fillSecondsLeft = math.max(0, math.ceil(fillEndsAt[modeId] - os.clock()))
	end

	return payload
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		local modeId = playerMode[player]
		if modeId then
			Remotes.QueueUpdate:FireClient(player, getStatus(player, modeId))
		else
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local taken = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerMode[player] = nil
		end
	end

	fillEndsAt[modeId] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	return taken
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	for _, player in players do
		HubService.enterArena(player)
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

local function startReadyMatch(modeId)
	local mode = MatchModes.get(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdates()
		return false
	end

	MatchStateService.setBusy(true)
	local players = takePlayers(modeId)
	if #players < mode.minPlayers then
		MatchStateService.setBusy(false)
		for _, queued in players do
			addToQueue(queued, modeId)
		end
		return false
	end

	launchMatch(modeId, players)
	broadcastQueueUpdates()
	return true
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local size = queueSize(modeId)
	if size < mode.minPlayers then
		return false
	end

	if mode.maxPlayers and size >= mode.maxPlayers then
		return startReadyMatch(modeId)
	end

	if modeId == "ffa" and fillEndsAt[modeId] and os.clock() >= fillEndsAt[modeId] then
		return startReadyMatch(modeId)
	end

	if modeId ~= "ffa" and size >= mode.minPlayers then
		return startReadyMatch(modeId)
	end

	return false
end

local function tryAllQueues()
	for modeId, _ in pairs(queues) do
		if tryStartMatch(modeId) then
			break
		end
	end
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillEndsAt[modeId] = os.clock() + mode.fillTimeout

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		tryStartMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	local size = queueSize(modeId)

	if modeId == "ffa" then
		if size < mode.minPlayers then
			fillEndsAt[modeId] = nil
			fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
		elseif size >= mode.minPlayers and not fillEndsAt[modeId] then
			startFillTimer(modeId)
		end
	end

	tryStartMatch(modeId)
	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	addToQueue(player, modeId)
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	broadcastQueueUpdates()
end

function MatchmakingService.removePlayer(player)
	removeFromQueue(player)
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

function MatchmakingService.init()
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.removePlayer(player)
		task.defer(broadcastQueueUpdates)
	end)

	MatchStateService.onArenaFreed(function()
		tryAllQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for _, player in Players:GetPlayers() do
				if playerMode[player] then
					Remotes.QueueUpdate:FireClient(player, getStatus(player, playerMode[player]))
				end
			end
		end
	end)
end

return MatchmakingService
