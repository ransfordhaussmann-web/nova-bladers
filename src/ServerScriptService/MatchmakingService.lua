local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady
local MatchEnded

local queues = {}
local playerQueue = {}
local fillTokens = {}
local callbacks = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getPlayerNames(playerList)
	local names = {}
	for _, player in playerList do
		table.insert(names, player.Name)
	end
	return names
end

local function getQueueStatus(modeId, count)
	local mode = MatchModes.get(modeId)
	if not mode then
		return "waiting"
	end
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	if count >= mode.minPlayers then
		return "ready"
	end
	return "waiting"
end

local function buildQueuePayload(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = getQueueStatus(modeId, count),
		playerNames = getPlayerNames(queue),
		inQueue = false,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			modeId = nil,
			status = "idle",
		})
		return
	end

	local payload = buildQueuePayload(modeId)
	payload.inQueue = true
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	broadcastQueueUpdate(modeId)
end

local function popPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local selected = {}
	local take = math.min(count, #queue)
	for _ = 1, take do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(selected, player)
			playerQueue[player] = nil
		end
	end
	return selected
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1

	for _, player in playerList do
		if callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(playerList, modeId)
	broadcastQueueUpdate(modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = ensureQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "ffa" and count < mode.maxPlayers then
		local token = (fillTokens[modeId] or 0) + 1
		fillTokens[modeId] = token
		task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			if token ~= fillTokens[modeId] then
				return
			end
			local currentQueue = ensureQueue(modeId)
			if #currentQueue < mode.minPlayers or MatchStateService.isArenaBusy() then
				broadcastQueueUpdate(modeId)
				return
			end
			local players = popPlayers(modeId, math.min(#currentQueue, mode.maxPlayers))
			launchMatch(modeId, players)
		end)
		broadcastQueueUpdate(modeId)
		return
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	launchMatch(modeId, players)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return true
	end

	removeFromQueue(player)
	table.insert(ensureQueue(modeId), player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player)
		return
	end
	removeFromQueue(player)
	sendQueueUpdate(player)
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

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	for _, modeId in { "training", "pvp", "ffa" } do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.init(opts)
	callbacks = opts or {}
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
