local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillToken = 0
local leaveHubForMatch
local getPlayerPhase

local function countQueue(modeId)
	return #queues[modeId]
end

local function removeFromAllQueues(player)
	local previousMode = playerMode[player]
	if not previousMode then
		return nil
	end

	local queue = queues[previousMode]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
	return previousMode
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local waiting = countQueue(modeId)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		waiting = waiting,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = "waiting",
	}

	if MatchStateService.isArenaBusy() then
		payload.status = "pending"
		payload.message = "Arena belegt — Warteschlange"
	elseif modeId == "ffa" and waiting >= mode.minPlayers and waiting < mode.maxPlayers then
		payload.status = "filling"
		payload.message = string.format("Start in bis zu %ds", MatchmakingConfig.FFA_FILL_TIMEOUT)
	end

	return payload
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerMode[player] then
			broadcastQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, amount)
	local selected = {}
	local queue = queues[modeId]
	for _ = 1, math.min(amount, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerMode[nextPlayer] = nil
			table.insert(selected, nextPlayer)
		end
	end
	return selected
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		for index = #playerList, 1, -1 do
			local player = playerList[index]
			table.insert(queues[modeId], 1, player)
			playerMode[player] = modeId
		end
		broadcastAllQueueUpdates()
		return
	end

	for _, player in playerList do
		if leaveHubForMatch then
			leaveHubForMatch(player)
		end
		broadcastQueueUpdate(player)
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local waiting = countQueue(modeId)
	if waiting < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if waiting >= mode.maxPlayers then
			ffaFillToken += 1
			startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		end
		return
	end

	startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
end

local function scheduleFfaFill()
	local token = ffaFillToken + 1
	ffaFillToken = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end

		local waiting = countQueue("ffa")
		local mode = MatchModes.ffa
		if waiting >= mode.minPlayers and waiting <= mode.maxPlayers then
			startMatch("ffa", popPlayers("ffa", waiting))
		end
	end)
end

local function processQueues()
	if MatchStateService.isArenaBusy() then
		broadcastAllQueueUpdates()
		return
	end

	tryStartMode("training")
	if MatchStateService.isArenaBusy() then
		return
	end

	tryStartMode("pvp")
	if MatchStateService.isArenaBusy() then
		return
	end

	local ffaWaiting = countQueue("ffa")
	if ffaWaiting >= MatchModes.ffa.maxPlayers then
		tryStartMode("ffa")
	end
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.getQueueCounts()
	return {
		training = countQueue("training"),
		pvp = countQueue("pvp"),
		ffa = countQueue("ffa"),
	}
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerMode[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getRecommendedMode()
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if getPlayerPhase and getPlayerPhase(player) ~= "hub" then
		return false
	end

	if playerMode[player] == modeId then
		broadcastQueueUpdate(player)
		return true
	end

	removeFromAllQueues(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if modeId == "ffa" and countQueue("ffa") == mode.minPlayers then
		scheduleFfaFill()
	end

	broadcastQueueUpdate(player)
	processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return false
	end

	removeFromAllQueues(player)

	if countQueue("ffa") < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
	end

	broadcastQueueUpdate(player)
	processQueues()
	return true
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	processQueues()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
	if countQueue("ffa") < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
	end
	task.defer(processQueues)
end

function MatchmakingService.init(options)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	leaveHubForMatch = options.leaveHubForMatch
	getPlayerPhase = options.getPlayerPhase

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
