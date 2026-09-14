local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}

local function resolveAutoModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.AUTO_MODE_PLAYER_THRESHOLDS.ffa then
		return "ffa"
	elseif count >= MatchmakingConfig.AUTO_MODE_PLAYER_THRESHOLDS.pvp then
		return "pvp"
	end
	return "training"
end

local function getQueueStatus()
	if GameMatchState.isArenaBusy() then
		return "pending"
	end
	return "waiting"
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	local position = 0
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #list,
		position = position,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
		status = getQueueStatus(),
		inQueue = true,
	}
end

local function broadcastQueueUpdate(modeId)
	local list = queues[modeId]
	for _, player in list do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function clearPlayerFromQueues(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local list = queues[entry.modeId]
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, index)
			break
		end
	end

	playerQueue[player] = nil
	broadcastQueueUpdate(entry.modeId)
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function takePlayers(modeId, count)
	local list = queues[modeId]
	local taken = {}
	local amount = math.min(count, #list)

	for _ = 1, amount do
		local player = table.remove(list, 1)
		if player then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end

	broadcastQueueUpdate(modeId)
	return taken
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local count = #queues[modeId]
	return count >= mode.minPlayers
end

local function tryLaunchMode(modeId)
	if GameMatchState.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not canStartMode(modeId) then
		return false
	end

	local playerCount = math.min(#queues[modeId], mode.maxPlayers)
	local players = takePlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for index = #players, 1, -1 do
			table.insert(queues[modeId], 1, players[index])
			playerQueue[players[index]] = { modeId = modeId }
		end
		broadcastQueueUpdate(modeId)
		return false
	end

	cancelFillTimer(modeId)
	GameMatchState.setArenaBusy(true)
	HubService.preparePlayersForMatch(players)
	Bindables.MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
	return true
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		return
	end
	if #queues[modeId] >= mode.maxPlayers then
		tryLaunchMode(modeId)
		return
	end
	if #queues[modeId] < mode.minPlayers then
		cancelFillTimer(modeId)
		return
	end

	local token = (fillTokens[modeId] or 0) + 1
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if GameMatchState.isArenaBusy() then
			return
		end
		if #queues[modeId] >= mode.minPlayers then
			tryLaunchMode(modeId)
		end
	end)
end

local function tryStartQueues()
	if GameMatchState.isArenaBusy() then
		for _, modeId in MatchModes.getOrderedIds() do
			broadcastQueueUpdate(modeId)
		end
		return
	end

	for _, modeId in MatchModes.getOrderedIds() do
		local mode = MatchModes.get(modeId)
		local count = #queues[modeId]

		if count >= mode.maxPlayers then
			if tryLaunchMode(modeId) then
				return
			end
		elseif count >= mode.minPlayers then
			if mode.fillTimeout > 0 then
				scheduleFillTimer(modeId)
			elseif tryLaunchMode(modeId) then
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "auto" then
		modeId = resolveAutoModeId()
	end
	if not MatchModes.isValid(modeId) then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end

	clearPlayerFromQueues(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	broadcastQueueUpdate(modeId)
	tryStartQueues()
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	clearPlayerFromQueues(player)
	cancelFillTimer(modeId)
	tryStartQueues()

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

function MatchmakingService.getPlayerMode(player)
	local entry = playerQueue[player]
	if entry then
		return entry.modeId
	end
	return nil
end

function MatchmakingService.onArenaFree()
	GameMatchState.setArenaBusy(false)
	tryStartQueues()
end

function MatchmakingService.start()
	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
