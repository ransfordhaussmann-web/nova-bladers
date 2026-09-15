local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local pendingStarts = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function countValid(queued)
	local n = 0
	for _, player in queued do
		if player.Parent then
			n += 1
		end
	end
	return n
end

local function compactQueue(modeId)
	local queued = getQueue(modeId)
	local compact = {}
	for _, player in queued do
		if player.Parent then
			table.insert(compact, player)
		else
			playerMode[player] = nil
		end
	end
	queues[modeId] = compact
	return compact
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queued = compactQueue(modeId)
	local count = #queued
	local status = "waiting"
	if pendingStarts[modeId] then
		status = "pending"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = true,
		position = nil,
	}
end

local function sendQueueUpdate(player, modeId)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
end

local function broadcastQueue(modeId)
	local queued = compactQueue(modeId)
	for _, player in queued do
		sendQueueUpdate(player, modeId)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function leaveQueue(player, silent)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	local queued = getQueue(modeId)
	for i, queuedPlayer in queued do
		if queuedPlayer == player then
			table.remove(queued, i)
			break
		end
	end

	if not silent and player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueue(modeId)

	if pendingStarts[modeId] then
		local mode = MatchModes.get(modeId)
		if countValid(getQueue(modeId)) < mode.minPlayers then
			pendingStarts[modeId] = nil
		end
	end

	if fillTimers[modeId] then
		local mode = MatchModes.get(modeId)
		if countValid(getQueue(modeId)) < mode.minPlayers then
			clearFillTimer(modeId)
		end
	end
end

local function takePlayersFromQueue(modeId, amount)
	local queued = compactQueue(modeId)
	local picked = {}
	for i = 1, math.min(amount, #queued) do
		table.insert(picked, queued[i])
	end

	queues[modeId] = {}
	clearFillTimer(modeId)
	pendingStarts[modeId] = nil

	for _, player in picked do
		playerMode[player] = nil
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
		end
	end

	return picked
end

local function startMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queued = compactQueue(modeId)
	if #queued < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueue(modeId)
		return
	end

	local count = math.min(#queued, mode.maxPlayers)
	local players = takePlayersFromQueue(modeId, count)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	MatchStateService.setArenaBusy(true)
	for _, player in players do
		if HubService.leaveHubForMatch then
			HubService.leaveHubForMatch(player)
		end
	end
	MatchReady:Fire(modeId, players)
end

local function scheduleFillTimeout(modeId)
	if fillTimers[modeId] then
		return
	end

	local mode = MatchModes.get(modeId)
	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
	local token = {}
	fillTimers[modeId] = token

	task.delay(timeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		startMatch(modeId)
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queued = compactQueue(modeId)
	local count = #queued

	if count == 0 then
		clearFillTimer(modeId)
		pendingStarts[modeId] = nil
		return
	end

	if count >= mode.maxPlayers then
		startMatch(modeId)
		return
	end

	if count >= mode.minPlayers then
		if modeId == "ffa" then
			scheduleFillTimeout(modeId)
		else
			startMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if playerMode[player] then
		if playerMode[player] == modeId then
			sendQueueUpdate(player, modeId)
			return true
		end
		leaveQueue(player, true)
	end

	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId
	sendQueueUpdate(player, modeId)
	broadcastQueue(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player, false)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFree()
	for modeId, _ in pairs(queues) do
		if pendingStarts[modeId] then
			evaluateQueue(modeId)
			if pendingStarts[modeId] and not MatchStateService.isArenaBusy() then
				startMatch(modeId)
			end
		end
	end
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchModes.suggestForPlayerCount(#Players:GetPlayers())
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player, true)
	end)

	MatchStateService.onArenaFree(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
