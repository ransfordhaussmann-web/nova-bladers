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
local fillTimers = {}
local fillToken = {}

local function removeFromQueueList(list, player)
	for index, queued in list do
		if queued == player then
			table.remove(list, index)
			return true
		end
	end
	return false
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return nil
	end

	local size = getQueueSize(modeId)
	local pending = MatchStateService.isBusy()
	local status = pending and "pending" or "searching"

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillTimeout = modeId == "ffa" and MatchmakingConfig.FFA_FILL_TIMEOUT or nil,
	}
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerMode[player] then
			local payload = buildQueuePayload(player)
			if payload then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end
	end
end

local function cancelFillTimer(modeId)
	fillToken[modeId] = (fillToken[modeId] or 0) + 1
	fillTimers[modeId] = nil
end

local function popPlayers(modeId, count)
	local list = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatch(modeId, takeCount)
	if MatchStateService.isBusy() then
		broadcastQueueUpdates()
		return
	end

	local playerList = popPlayers(modeId, takeCount)
	if #playerList == 0 then
		return
	end

	MatchStateService.setBusy(true)
	cancelFillTimer(modeId)

	for _, player in playerList do
		HubService.enterArena(player)
	end

	MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})

	broadcastQueueUpdates()
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isBusy() then
		broadcastQueueUpdates()
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if size >= mode.maxPlayers then
			launchMatch(modeId, mode.maxPlayers)
			return
		end

		if fillTimers[modeId] then
			return
		end

		fillTimers[modeId] = true
		fillToken[modeId] = (fillToken[modeId] or 0) + 1
		local token = fillToken[modeId]

		task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			if token ~= fillToken[modeId] then
				return
			end
			fillTimers[modeId] = nil

			if MatchStateService.isBusy() then
				broadcastQueueUpdates()
				return
			end

			local currentSize = getQueueSize(modeId)
			if currentSize >= mode.minPlayers then
				launchMatch(modeId, math.min(currentSize, mode.maxPlayers))
			end
		end)
		return
	end

	launchMatch(modeId, mode.maxPlayers)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueueList(queues[modeId], player)
	playerMode[player] = nil

	if modeId == "ffa" and getQueueSize(modeId) < MatchModes.get("ffa").minPlayers then
		cancelFillTimer(modeId)
	end

	HubService.returnToHub(player)
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

	if HubService.getPhase(player) == "arena" then
		return
	end

	if playerMode[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	HubService.enterQueue(player, modeId)

	broadcastQueueUpdates()
	tryStartMatch(modeId)
end

function MatchmakingService.onArenaFree()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueueList(queues[modeId], player)
	playerMode[player] = nil

	if modeId == "ffa" and getQueueSize(modeId) < MatchModes.get("ffa").minPlayers then
		cancelFillTimer(modeId)
	end
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
		MatchmakingService.onPlayerRemoving(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
