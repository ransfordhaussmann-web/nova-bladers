local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local MODE_IDS = { "training", "pvp", "ffa" }

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTokens = {}
local initialized = false

local function ensureQueues()
	for _, modeId in MODE_IDS do
		queues[modeId] = queues[modeId] or {}
	end
end

local function getQueuePlayers(modeId)
	local list = {}
	for _, player in queues[modeId] or {} do
		if player.Parent then
			table.insert(list, player)
		end
	end
	queues[modeId] = list
	return list
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local queued = getQueuePlayers(modeId)
	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif modeId == "ffa" and #queued >= mode.minPlayers and fillTokens[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queued,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
		inQueue = player ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId)
	if not payload then
		return
	end

	for _, player in getQueuePlayers(modeId) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for _, modeId in MODE_IDS do
		broadcastQueueUpdate(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local list = getQueuePlayers(modeId)
	for i, queued in list do
		if queued == player then
			table.remove(list, i)
			break
		end
	end
	queues[modeId] = list
	broadcastQueueUpdate(modeId)
end

local function leaveHubForArena(player)
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
		leaveHubForArena(player)
	end

	fillTokens[modeId] = nil
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function canStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queued = getQueuePlayers(modeId)
	return #queued >= mode.minPlayers
end

local function tryStartMode(modeId)
	if not canStartMode(modeId) then
		return
	end

	local mode = MatchModes.get(modeId)
	local queued = getQueuePlayers(modeId)

	if #queued >= mode.maxPlayers then
		fillTokens[modeId] = nil
		local roster = {}
		for i = 1, mode.maxPlayers do
			table.insert(roster, queued[i])
		end
		startMatch(modeId, roster)
		return
	end

	if modeId == "ffa" and mode.fillTimeout > 0 then
		if #queued < mode.maxPlayers and not fillTokens[modeId] then
			fillTokens[modeId] = {}
			local token = fillTokens[modeId]
			task.delay(mode.fillTimeout, function()
				if fillTokens[modeId] ~= token then
					return
				end
				fillTokens[modeId] = nil
				if canStartMode(modeId) then
					local ready = getQueuePlayers(modeId)
					local roster = {}
					for i = 1, math.min(#ready, mode.maxPlayers) do
						table.insert(roster, ready[i])
					end
					if #roster >= mode.minPlayers then
						startMatch(modeId, roster)
					end
				end
			end)
			broadcastQueueUpdate(modeId)
			return
		end
	end

	local roster = {}
	for i = 1, math.min(#queued, mode.maxPlayers) do
		table.insert(roster, queued[i])
	end
	startMatch(modeId, roster)
end

local function tryStartAllQueues()
	for _, modeId in MODE_IDS do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local payload = buildQueuePayload(modeId, player)
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastQueueUpdate(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	if fillTokens[modeId] and #getQueuePlayers(modeId) < MatchModes.get(modeId).minPlayers then
		fillTokens[modeId] = nil
	end
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
		status = "idle",
	})
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
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()
	ensureQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		tryStartAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastAllQueues()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
