local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillToken = 0

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId] or MatchmakingConfig.MODES.training
end

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function findInQueue(modeId, player)
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			return i
		end
	end
	return nil
end

local function removeFromAllQueues(player)
	local previousMode = playerMode[player]
	if not previousMode then
		return
	end

	local index = findInQueue(previousMode, player)
	if index then
		table.remove(queues[previousMode], index)
	end
	playerMode[player] = nil

	if previousMode == "ffa" then
		local config = getModeConfig("ffa")
		if #queues.ffa < config.minPlayers then
			ffaFillToken += 1
		end
	end
end

local function buildStatus(modeId, player)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local position = findInQueue(modeId, player) or 0

	local status = "waiting"
	if MatchState.busy then
		status = "pending"
	elseif modeId == "ffa" and #queue >= config.minPlayers and #queue < config.maxPlayers then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		position = position,
		queueSize = #queue,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		inQueue = position > 0,
	}
end

local function sendUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildStatus(modeId, player))
end

local function broadcastMode(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			sendUpdate(player)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastMode(modeId)
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	if MatchState.busy then
		for i = #playerList, 1, -1 do
			local player = playerList[i]
			table.insert(queues[modeId], 1, player)
			playerMode[player] = modeId
		end
		broadcastMode(modeId)
		return
	end

	ffaFillToken += 1
	MatchState.busy = true

	for _, player in playerList do
		HubService.enterArena(player)
	end

	Bindables.MatchReady:Fire({
		players = playerList,
		mode = modeId,
	})

	broadcastAllQueues()
end

local function tryStartMode(modeId)
	if MatchState.busy then
		return
	end

	local config = getModeConfig(modeId)
	local queue = queues[modeId]

	if modeId == "training" and #queue >= config.minPlayers then
		startMatch(modeId, popPlayers(modeId, 1))
	elseif modeId == "pvp" and #queue >= config.minPlayers then
		startMatch(modeId, popPlayers(modeId, 2))
	elseif modeId == "ffa" and #queue >= config.maxPlayers then
		startMatch(modeId, popPlayers(modeId, config.maxPlayers))
	end
end

local function scheduleFfaFill()
	local config = getModeConfig("ffa")
	if #queues.ffa < config.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(config.fillTimeout, function()
		if token ~= ffaFillToken or MatchState.busy then
			return
		end
		if #queues.ffa >= config.minPlayers then
			local count = math.min(#queues.ffa, config.maxPlayers)
			startMatch("ffa", popPlayers("ffa", count))
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end
	if MatchState.busy and playerMode[player] == modeId then
		sendUpdate(player)
		return
	end

	removeFromAllQueues(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	sendUpdate(player)
	broadcastMode(modeId)

	if modeId == "ffa" and #queues.ffa == getModeConfig("ffa").minPlayers then
		scheduleFfaFill()
	end

	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local modeId = playerMode[player]
	removeFromAllQueues(player)
	broadcastMode(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.onMatchEnded()
	broadcastAllQueues()

	for modeId in queues do
		tryStartMode(modeId)
		if modeId == "ffa" and #queues.ffa >= getModeConfig("ffa").minPlayers then
			scheduleFfaFill()
		end
	end
end

function MatchmakingService.isPlayerQueued(player)
	return playerMode[player] ~= nil
end

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

return MatchmakingService
