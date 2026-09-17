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

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillEndAt = nil
local ffaFillToken = 0

local function getMode(modeId)
	return MatchModes[modeId]
end

local function isValidModeId(modeId)
	return MatchModes[modeId] ~= nil
end

local function pruneQueue(modeId)
	local queue = queues[modeId]
	local cleaned = {}
	for _, player in queue do
		if player.Parent and playerMode[player] == modeId then
			table.insert(cleaned, player)
		end
	end
	queues[modeId] = cleaned
end

local function queueCount(modeId)
	pruneQueue(modeId)
	return #queues[modeId]
end

local function getQuickMatchModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(requestedModeId)
	if requestedModeId == "quick" then
		return getQuickMatchModeId()
	end
	if isValidModeId(requestedModeId) then
		return requestedModeId
	end
	return nil
end

local function buildQueuePayload(player, modeId)
	local mode = getMode(modeId)
	local count = queueCount(modeId)
	local status = "waiting"
	if MatchStateService.isInMatch() then
		status = "pending"
	end

	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = count,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeLeft = nil,
	}

	if modeId == "ffa" and ffaFillEndAt and count >= mode.minPlayers then
		payload.fillTimeLeft = math.max(0, math.ceil(ffaFillEndAt - os.clock()))
		payload.status = "filling"
	end

	return payload
end

local function sendQueueUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastQueueUpdates(modeId)
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		sendQueueUpdate(player)
	end
end

local function clearFfaFillTimer()
	ffaFillEndAt = nil
	ffaFillToken += 1
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if modeId == "ffa" and queueCount("ffa") < MatchModes.ffa.minPlayers then
		clearFfaFillTimer()
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
end

local function popPlayers(modeId, count)
	pruneQueue(modeId)
	local picked = {}
	local queue = queues[modeId]
	while #picked < count and #queue > 0 do
		local player = table.remove(queue, 1)
		playerMode[player] = nil
		sendQueueUpdate(player)
		table.insert(picked, player)
	end
	broadcastQueueUpdates(modeId)
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	clearFfaFillTimer()

	for _, player in playerList do
		HubService.prepareForMatch(player)
	end

	Bindables.MatchReady:Fire({
		players = playerList,
		mode = modeId,
	})
end

local function tryStartInstantMode(modeId)
	if MatchStateService.isInMatch() then
		return
	end

	local mode = getMode(modeId)
	if not mode.instant then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	launchMatch(modeId, players)
end

local function tryStartFfa(forceStart)
	if MatchStateService.isInMatch() then
		return
	end

	local mode = MatchModes.ffa
	local count = queueCount("ffa")
	if count < mode.minPlayers then
		clearFfaFillTimer()
		return
	end

	if count >= mode.maxPlayers then
		forceStart = true
	end

	if not forceStart then
		if not ffaFillEndAt then
			ffaFillToken += 1
			local token = ffaFillToken
			ffaFillEndAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			broadcastQueueUpdates("ffa")

			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if token ~= ffaFillToken or MatchStateService.isInMatch() then
					return
				end
				tryStartFfa(true)
			end)
		end
		return
	end

	clearFfaFillTimer()
	local countAfterWait = queueCount("ffa")
	if countAfterWait < mode.minPlayers then
		return
	end

	local takeCount = math.min(countAfterWait, mode.maxPlayers)
	local players = popPlayers("ffa", takeCount)
	launchMatch("ffa", players)
end

local function processAllQueues()
	if MatchStateService.isInMatch() then
		for modeId in queues do
			broadcastQueueUpdates(modeId)
		end
		return
	end

	tryStartInstantMode("training")
	tryStartInstantMode("pvp")
	tryStartFfa()
end

function MatchmakingService.joinQueue(player, requestedModeId)
	local modeId = resolveModeId(requestedModeId)
	if not modeId then
		return
	end

	if playerMode[player] then
		if playerMode[player] == modeId then
			sendQueueUpdate(player)
			return
		end
		removeFromQueue(player)
	end

	playerMode[player] = modeId
	table.insert(queues[modeId], player)
	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	processAllQueues()
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, requestedModeId)
		if typeof(requestedModeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, requestedModeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	MatchStateService.onIdle(function()
		processAllQueues()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
