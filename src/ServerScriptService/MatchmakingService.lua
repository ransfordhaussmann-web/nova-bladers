local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local callbacks = {}
local isMatchIdle = function()
	return true
end

local MODE_ORDER = { "ffa", "pvp", "training" }

local function getModeLabel(modeId)
	if modeId == "ffa" then
		return "FFA"
	elseif modeId == "pvp" then
		return "1v1 PvP"
	end
	return "Training"
end

local function getQueuePosition(modeId, player)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index, #queue
		end
	end
	return nil, #queue
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local position, total = getQueuePosition(modeId, player)
	local config = HubConfig.QUEUE_MODES[modeId]
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = modeId,
		modeLabel = getModeLabel(modeId),
		position = position,
		total = total,
		needed = config.min,
	})
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdates()
end

local function popPlayers(modeId)
	local config = HubConfig.QUEUE_MODES[modeId]
	local queue = queues[modeId]
	local count = math.min(#queue, config.max)
	local players = {}

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(players, player)
		end
	end

	broadcastQueueUpdates()
	return players
end

local function tryStartMatch()
	if not isMatchIdle() then
		return
	end

	for _, modeId in MODE_ORDER do
		local config = HubConfig.QUEUE_MODES[modeId]
		if #queues[modeId] >= config.min then
			local players = popPlayers(modeId)
			if #players >= config.min then
				if callbacks.onPlayersMatched then
					callbacks.onPlayersMatched(players, modeId)
				end
				MatchReady:Fire(players, modeId)
			end
			return
		end
	end
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.setMatchIdleChecker(checker)
	isMatchIdle = checker or function()
		return true
	end
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= HubConfig.QUEUE_MODES.ffa.min then
		return "ffa"
	elseif count >= HubConfig.QUEUE_MODES.pvp.min then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if not HubConfig.QUEUE_MODES[modeId] then
		return false
	end
	if not isMatchIdle() and not playerQueue[player] then
		return false
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	sendQueueUpdate(player)
	broadcastQueueUpdates()
	tryStartMatch()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end
	removeFromQueue(player)
	return true
end

function MatchmakingService.init()
	Remotes.JoinQueue.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.LeaveQueue.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(HubConfig.QUEUE_POLL_INTERVAL)
			tryStartMatch()
		end
	end)
end

return MatchmakingService
