--[[
	MatchmakingService — queue players by mode and start matches when ready.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local remotes
local matchReadyEvent
local matchEndedEvent
local getPhase
local leaveHubForArena

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
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

	playerMode[player] = nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if isValidPlayer(queuedPlayer) then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif mode and #queue >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		players = names,
		status = status,
		inQueue = playerMode[player] == modeId,
	}
end

local function broadcastQueue(modeId)
	if not remotes then
		return
	end

	for _, queuedPlayer in getQueue(modeId) do
		if isValidPlayer(queuedPlayer) then
			remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, queuedPlayer))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	local limit = math.min(count, #queue)

	for _ = 1, limit do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end

	return picked
end

local function startMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	clearFillTimer(modeId)

	local playerCount = math.min(#queue, mode.maxPlayers)
	local matchPlayers = popPlayers(modeId, playerCount)
	if #matchPlayers == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in matchPlayers do
		if remotes and isValidPlayer(player) then
			remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end

	broadcastAllQueues()
	matchReadyEvent:Fire(matchPlayers)
end

local function scheduleFillStart(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		startMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		clearFillTimer(modeId)
		broadcastQueue(modeId)
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if mode.maxPlayers > 1 and #queue < mode.maxPlayers and mode.fillTimeout then
		scheduleFillStart(modeId)
		broadcastQueue(modeId)
		return
	end

	startMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "invalid_player"
	end

	if getPhase and getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, player)
	playerMode[player] = modeId

	broadcastQueue(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return false
	end

	local modeId = playerMode[player]
	removeFromQueue(player)
	clearFillTimer(modeId)

	if remotes and isValidPlayer(player) then
		remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			inQueue = false,
		})
	end

	broadcastQueue(modeId)
	return true
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	for modeId in queues do
		evaluateQueue(modeId)
	end
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyEvent = options.matchReadyEvent
	matchEndedEvent = options.matchEndedEvent
	getPhase = options.getPhase
	leaveHubForArena = options.leaveHubForArena

	if matchEndedEvent then
		matchEndedEvent.Event:Connect(function()
			MatchmakingService.onMatchEnded()
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerMode[player]
		if modeId then
			removeFromQueue(player)
			clearFillTimer(modeId)
			broadcastQueue(modeId)
		end
	end)
end

return MatchmakingService
