local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}
local startTokens = {}
local started = false

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "queued"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	return {
		status = status,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queued = #queue,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
end

local function broadcastAllInQueue(modeId)
	for _, player in queues[modeId] do
		broadcastQueue(player, modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	local mode = MatchModes.get(modeId)
	if mode and #queues[modeId] < mode.minPlayers then
		fillTokens[modeId] = nil
		startTokens[modeId] = nil
	end

	broadcastAllInQueue(modeId)
end

local function addToQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastAllInQueue(modeId)
	return true
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	broadcastAllInQueue(modeId)
	return taken
end

local function fireMatchReady(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)
	fillTokens[modeId] = nil

	for _, player in playerList do
		Remotes.QueueUpdate:FireClient(player, {
			status = "starting",
			modeId = modeId,
			modeLabel = MatchModes.get(modeId).label,
			queued = 0,
			required = #playerList,
			pending = false,
		})
	end

	MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 then
		if not fillTokens[modeId] then
			fillTokens[modeId] = {}
			local token = fillTokens[modeId]
			task.delay(mode.fillTimeout, function()
				if fillTokens[modeId] ~= token or MatchStateService.isArenaBusy() then
					return
				end
				fillTokens[modeId] = nil
				if #queues[modeId] >= mode.minPlayers then
					local players = takePlayers(modeId, mode.maxPlayers)
					fireMatchReady(modeId, players)
				end
			end)
		end

		if #queue >= mode.maxPlayers then
			fillTokens[modeId] = nil
			local players = takePlayers(modeId, mode.maxPlayers)
			fireMatchReady(modeId, players)
		end
		return
	end

	startTokens[modeId] = {}
	local token = startTokens[modeId]
	task.delay(MatchmakingConfig.MATCH_START_DELAY, function()
		if startTokens[modeId] ~= token or MatchStateService.isArenaBusy() then
			return
		end
		startTokens[modeId] = nil
		if #queues[modeId] < mode.minPlayers then
			return
		end
		local players = takePlayers(modeId, mode.maxPlayers)
		fireMatchReady(modeId, players)
	end)
end

local function processQueues()
	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end

	if modeId == "auto" then
		modeId = MatchModes.recommendForPlayerCount(#Players:GetPlayers())
	end

	if not addToQueue(player, modeId) then
		return
	end

	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	for _, modeId in { "training", "pvp", "ffa" } do
		broadcastAllInQueue(modeId)
	end
	processQueues()
end

function MatchmakingService.start(hubCallbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "auto"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		MatchmakingService.onArenaFreed()
	end)

	if hubCallbacks and hubCallbacks.onMatchReady then
		MatchReady.Event:Connect(function(playerList, modeId)
			hubCallbacks.onMatchReady(playerList, modeId)
		end)
	end

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
