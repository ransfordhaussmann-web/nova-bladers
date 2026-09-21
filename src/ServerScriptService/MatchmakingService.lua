local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerMode = {}
local fillTokens = {}

for _, mode in MatchModes.all() do
	queues[mode.id] = {}
	fillTokens[mode.id] = 0
end

local function getQueueList(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local list = getQueueList(modeId)
	for i, queued in list do
		if queued == player then
			table.remove(list, i)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and #list < MatchModes.ffa.minPlayers then
		fillTokens.ffa += 1
	end
end

local function queuePosition(player, modeId)
	local list = getQueueList(modeId)
	for i, queued in list do
		if queued == player then
			return i
		end
	end
	return nil
end

local function buildStatus(modeId)
	local mode = MatchModes.get(modeId)
	local count = #getQueueList(modeId)

	if MatchStateService.isBusy() then
		return "pending"
	end
	if count >= mode.maxPlayers then
		return "ready"
	end
	if mode.instantStart and count >= mode.minPlayers then
		return "ready"
	end
	return "waiting"
end

local function buildPayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local names = {}
	for _, queued in list do
		if queued.Parent then
			table.insert(names, queued.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = queuePosition(player, modeId),
		status = buildStatus(modeId),
		playerNames = names,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player)
	local modeId = playerMode[player]
	if not modeId or not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildPayload(player, modeId))
end

local function broadcastQueue()
	for player in playerMode do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local list = getQueueList(modeId)
	local picked = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerMode[player] = nil
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setBusy(true)

	for _, player in playerList do
		HubService.enterArena(player)
	end

	Bindables.MatchReady:Fire(playerList, modeId)
	broadcastQueue()
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local count = #getQueueList(modeId)
	if count < mode.minPlayers then
		return false
	end

	if not mode.instantStart and count < mode.maxPlayers then
		return false
	end

	local players = popPlayers(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		for i = #players, 1, -1 do
			table.insert(getQueueList(modeId), 1, players[i])
			playerMode[players[i]] = modeId
		end
		return false
	end

	launchMatch(modeId, players)
	return true
end

local function tryStartAny()
	for _, modeId in MatchmakingConfig.START_PRIORITY do
		if tryStartMode(modeId) then
			return
		end
	end
end

local function scheduleFfaFill()
	local mode = MatchModes.ffa
	if #getQueueList("ffa") < mode.minPlayers then
		return
	end

	fillTokens.ffa += 1
	local token = fillTokens.ffa

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= fillTokens.ffa then
			return
		end
		if MatchStateService.isBusy() then
			return
		end
		if #getQueueList("ffa") < mode.minPlayers then
			return
		end
		tryStartMode("ffa")
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end
	if playerMode[player] == modeId then
		sendQueueUpdate(player)
		return true
	end
	if HubService.getPhase(player) == "arena" then
		return false, "in_match"
	end

	removeFromQueue(player)
	table.insert(getQueueList(modeId), player)
	playerMode[player] = modeId

	sendQueueUpdate(player)
	broadcastQueue()

	if modeId == "ffa" then
		scheduleFfaFill()
	end

	tryStartMode(modeId)
	return true
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local modeId = MatchModes.resolveQuickMatch(count)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueue()
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(tryStartAny)
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueue()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
