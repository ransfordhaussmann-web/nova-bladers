local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady
local ArenaFree

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}
local pendingMatch = nil
local started = false

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function playerNamesForMode(modeId)
	local names = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end
	return names
end

local function buildQueuePayload(modeId, player, status)
	local mode = getModeConfig(modeId)
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = queueCount(modeId),
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		players = playerNamesForMode(modeId),
		status = status or "waiting",
		pendingArena = GameMatchState.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local list = queues[modeId]
	for i = #list, 1, -1 do
		if list[i] == player then
			table.remove(list, i)
		end
	end
	playerQueue[player] = nil
	broadcastQueueUpdate(modeId)
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function takePlayersFromQueue(modeId, count)
	local list = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #list) do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	broadcastQueueUpdate(modeId)
	return picked
end

local function launchMatch(modeId, playerList)
	cancelFillTimer(modeId)
	pendingMatch = nil

	for _, player in playerList do
		removeFromQueue(player)
		HubService.enterArena(player)
	end

	GameMatchState.setArenaBusy(true)
	MatchReady:Fire(playerList, modeId)
end

local function tryLaunchReadyMatch(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	local takeCount = math.min(count, mode.maxPlayers)
	local playerList = takePlayersFromQueue(modeId, takeCount)
	if #playerList < mode.minPlayers then
		for _, player in playerList do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = playerList }
		for _, player in playerList do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player, "pending"))
			end
		end
		return
	end

	launchMatch(modeId, playerList)
end

local function scheduleFillTimer(modeId)
	local mode = getModeConfig(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if queueCount(modeId) >= mode.minPlayers then
			tryLaunchReadyMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false, "invalid_mode"
	end
	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end
	if GameMatchState.isArenaBusy() and pendingMatch then
		return false, "arena_busy"
	end

	removeFromQueue(player)

	local mode = getModeConfig(modeId)
	local list = queues[modeId]
	if #list >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(list, player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if queueCount(modeId) >= mode.maxPlayers then
		tryLaunchReadyMatch(modeId)
	elseif queueCount(modeId) >= mode.minPlayers then
		if mode.minPlayers == mode.maxPlayers then
			tryLaunchReadyMatch(modeId)
		else
			scheduleFillTimer(modeId)
		end
	end

	return true
end

function MatchmakingService.joinQuickMatch(player)
	return MatchmakingService.joinQueue(player, getRecommendedModeId())
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	return true
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

local function onArenaFree()
	if pendingMatch and pendingMatch.players then
		local snapshot = pendingMatch
		pendingMatch = nil
		if not GameMatchState.isArenaBusy() then
			launchMatch(snapshot.modeId, snapshot.players)
		end
		return
	end

	for modeId, mode in MatchmakingConfig.MODES do
		if queueCount(modeId) >= mode.minPlayers then
			tryLaunchReadyMatch(modeId)
			break
		end
	end
end

local function onPlayerRemoving(player)
	removeFromQueue(player)
	if pendingMatch then
		for i = #pendingMatch.players, 1, -1 do
			if pendingMatch.players[i] == player then
				table.remove(pendingMatch.players, i)
			end
		end
		if #pendingMatch.players < getModeConfig(pendingMatch.modeId).minPlayers then
			for _, p in pendingMatch.players do
				if p.Parent then
					MatchmakingService.joinQueue(p, pendingMatch.modeId)
				end
			end
			pendingMatch = nil
		end
	end
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, _ = RemotesSetup.ensure()
	local _, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	ArenaFree = Bindables.ArenaFree

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(onArenaFree)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
end

return MatchmakingService
