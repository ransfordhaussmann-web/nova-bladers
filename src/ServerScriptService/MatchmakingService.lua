local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}
local started = false

local function getQueueList(modeId)
	return queues[modeId] or {}
end

local function findPlayerIndex(list, player)
	for i, queued in list do
		if queued == player then
			return i
		end
	end
	return nil
end

local function removeFromAllQueues(player)
	local previousMode = playerQueue[player]
	if not previousMode then
		return nil
	end

	local list = queues[previousMode]
	local index = findPlayerIndex(list, player)
	if index then
		table.remove(list, index)
	end
	playerQueue[player] = nil
	fillTokens[previousMode] = (fillTokens[previousMode] or 0) + 1
	return previousMode
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local position = findPlayerIndex(list, player) or #list
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif #list >= mode.minPlayers and modeId ~= "ffa" then
		status = "ready"
	elseif #list >= mode.minPlayers and modeId == "ffa" then
		status = "filling"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function buildIdlePayload()
	return {
		inQueue = false,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if modeId then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	else
		Remotes.QueueUpdate:FireClient(player, buildIdlePayload())
	end
end

local function broadcastQueue(modeId)
	for _, queued in getQueueList(modeId) do
		if queued.Parent then
			sendQueueUpdate(queued)
		end
	end
end

local function broadcastAllQueues()
	for _, player in Players:GetPlayers() do
		sendQueueUpdate(player)
	end
end

local function popQueuePlayers(modeId, count)
	local list = getQueueList(modeId)
	local picked = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function fireMatchReady(modeId, playerList)
	if #playerList == 0 then
		return
	end
	MatchStateService.setArenaBusy(true)
	for _, player in playerList do
		sendQueueUpdate(player)
	end
	MatchReady:Fire(modeId, playerList)
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	if #list < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		return
	end

	local players = popQueuePlayers(modeId, mode.maxPlayers)
	broadcastQueue(modeId)
	fireMatchReady(modeId, players)
end

local function scheduleFfaFill(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if MatchStateService.isArenaBusy() then
			return
		end

		local mode = MatchModes.get(modeId)
		local list = getQueueList(modeId)
		if #list < mode.minPlayers then
			return
		end

		local players = popQueuePlayers(modeId, mode.maxPlayers)
		broadcastQueue(modeId)
		fireMatchReady(modeId, players)
	end)
end

local function onQueueChanged(modeId)
	broadcastQueue(modeId)

	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	if #list < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #list == mode.minPlayers then
			scheduleFfaFill(modeId)
		end
		return
	end

	tryStartMode(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			sendQueueUpdate(player)
			return true
		end
		removeFromAllQueues(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromAllQueues(player)
	if modeId then
		broadcastQueue(modeId)
	end
	sendQueueUpdate(player)
	return modeId ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	broadcastAllQueues()

	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
		local list = getQueueList(mode.id)
		if mode.id == "ffa" and #list >= mode.minPlayers then
			scheduleFfaFill(mode.id)
		end
	end
end

function MatchmakingService.onMatchEnded()
	MatchmakingService.onArenaFreed()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
