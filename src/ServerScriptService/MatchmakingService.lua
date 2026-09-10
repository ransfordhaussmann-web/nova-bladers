local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTokens = {}
local callbacks = {
	isArenaBusy = function()
		return false
	end,
	onQueueUpdate = function(_player, _payload) end,
	onMatchReady = function(_modeId, _players) end,
}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
		fillTokens[modeId] = 0
	end
end

initQueues()

local function queueCount(modeId)
	return #queues[modeId]
end

local function buildStatus(player, modeId)
	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	local busy = callbacks.isArenaBusy()
	local status = "waiting"

	if busy then
		status = "pending"
	elseif count >= config.maxPlayers then
		status = "ready"
	elseif count >= config.minPlayers and config.fillTimeout == 0 then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		count = count,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = status,
		inQueue = true,
	}
end

local function notifyQueue(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			callbacks.onQueueUpdate(queuedPlayer, buildStatus(queuedPlayer, modeId))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
	fillTokens[modeId] += 1
	notifyQueue(modeId)
	return modeId
end

local function tryStartMatch(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	if callbacks.isArenaBusy() then
		notifyQueue(modeId)
		return
	end

	local count = queueCount(modeId)
	if count < config.minPlayers then
		return
	end

	local players = {}
	for index = 1, math.min(count, config.maxPlayers) do
		table.insert(players, queues[modeId][index])
	end

	for _, matchPlayer in players do
		removeFromQueue(matchPlayer)
	end

	callbacks.onMatchReady(modeId, players)
end

local function scheduleFillTimer(modeId)
	local config = getModeConfig(modeId)
	if not config or config.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]

	task.delay(config.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if queueCount(modeId) >= config.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.configure(newCallbacks)
	for key, handler in newCallbacks do
		callbacks[key] = handler
	end
end

function MatchmakingService.getPreferredModeId(playerCount)
	if playerCount >= 3 then
		return "ffa"
	elseif playerCount == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false, "invalid_mode"
	end

	if playerMode[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	notifyQueue(modeId)

	local config = getModeConfig(modeId)
	local count = queueCount(modeId)

	if count >= config.maxPlayers then
		tryStartMatch(modeId)
	elseif count >= config.minPlayers then
		if config.fillTimeout > 0 then
			if count == config.minPlayers then
				scheduleFillTimer(modeId)
			end
		else
			tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId then
		callbacks.onQueueUpdate(player, { inQueue = false })
	end
	return modeId ~= nil
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchEnded()
	for modeId in MatchmakingConfig.MODES do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

local function bindRemotes()
	local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
	local HubService = require(script.Parent.HubService)
	local Remotes, Bindables = RemotesSetup.ensure()

	MatchmakingService.configure({
		isArenaBusy = function()
			return MatchmakingService._arenaBusy == true
		end,
		onQueueUpdate = function(player, payload)
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, payload)
			end
		end,
		onMatchReady = function(modeId, playerList)
			MatchmakingService._arenaBusy = true
			for _, matchPlayer in playerList do
				HubService.leaveHubForMatch(matchPlayer)
			end
			Bindables.MatchReady:Fire(modeId, playerList)
		end,
	})

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getPreferredModeId(#Players:GetPlayers())
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchStarted.Event:Connect(function()
		MatchmakingService._arenaBusy = true
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService._arenaBusy = false
		task.defer(function()
			MatchmakingService.onMatchEnded()
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)
end

bindRemotes()

return MatchmakingService
