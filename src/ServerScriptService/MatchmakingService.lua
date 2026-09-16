local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local ffaFillScheduled = false
local started = false

local function getQueueList(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	queues[modeId] = list
	return list
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local list = getQueueList(modeId)
	for i, queued in list do
		if queued == player then
			table.remove(list, i)
			break
		end
	end
	queues[modeId] = list

	if modeId == "ffa" and #list < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
		ffaFillScheduled = false
	end
end

local function buildStatus(player, modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local count = #list
	local arenaBusy = MatchStateService.isBusy()
	local ready = count >= mode.minPlayers
	local status = "waiting"

	if arenaBusy and ready then
		status = "pending"
	elseif ready and modeId == "ffa" and count < mode.maxPlayers then
		status = "filling"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if modeId then
		Remotes.QueueUpdate:FireClient(player, buildStatus(player, modeId))
	else
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function broadcastQueueUpdates()
	for player, _ in playerQueue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	if #list < mode.minPlayers then
		return nil
	end

	local count = math.min(#list, mode.maxPlayers)
	local matchPlayers = {}
	for i = 1, count do
		table.insert(matchPlayers, list[i])
	end

	queues[modeId] = {}
	for _, player in matchPlayers do
		playerQueue[player] = nil
	end

	if modeId == "ffa" then
		ffaFillToken += 1
		ffaFillScheduled = false
	end

	return matchPlayers
end

local function launchMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdates()
		return
	end

	local matchPlayers = popPlayers(modeId)
	if not matchPlayers then
		return
	end

	MatchStateService.setBusy(true)
	for _, player in matchPlayers do
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, starting = true })
	end
	MatchReady:Fire(matchPlayers, modeId)
end

local function scheduleFfaFill()
	if ffaFillScheduled then
		return
	end
	ffaFillScheduled = true
	local token = ffaFillToken
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		ffaFillScheduled = false
		if token ~= ffaFillToken then
			return
		end
		launchMatch("ffa")
	end)
end

local function evaluateMode(modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	if #list < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #list >= mode.maxPlayers then
			launchMatch("ffa")
		else
			scheduleFfaFill()
			broadcastQueueUpdates()
		end
	else
		launchMatch(modeId)
	end
end

local function evaluateAllModes()
	for modeId, _ in MatchModes.all() do
		evaluateMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end
	if playerQueue[player] then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	evaluateMode(modeId)
	return true
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local modeId = "training"
	if count >= 3 then
		modeId = "ffa"
	elseif count == 2 then
		modeId = "pvp"
	end
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(evaluateAllModes)
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
