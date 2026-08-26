local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local gatherTokens = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countValid(queue)
	local n = 0
	for _, player in queue do
		if player.Parent then
			n += 1
		end
	end
	return n
end

local function getValidPlayers(queue, maxCount)
	local list = {}
	for _, player in queue do
		if player.Parent and #list < maxCount then
			table.insert(list, player)
		end
	end
	return list
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	if not config then
		return nil
	end
	local count = countValid(queues[modeId])
	return {
		mode = modeId,
		modeLabel = config.label,
		count = count,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		inQueue = playerQueue[player] == modeId,
		gathering = gatherTokens[modeId] ~= nil,
	}
end

local function broadcastQueueState(modeId)
	local payload = buildQueuePayload(modeId, nil)
	if not payload then
		return
	end
	for _, player in queues[modeId] do
		if player.Parent then
			local personal = buildQueuePayload(modeId, player)
			Remotes.QueueState:FireClient(player, personal)
		end
	end
end

local function removeFromQueue(player, silent)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end

	if not silent then
		broadcastQueueState(modeId)
	end
end

local function clearGather(modeId)
	gatherTokens[modeId] = nil
end

local function startMatch(modeId, players)
	clearGather(modeId)
	for _, player in players do
		removeFromQueue(player, true)
	end
	for modeKey in queues do
		broadcastQueueState(modeKey)
	end
	Bindables.MatchReady:Fire({
		players = players,
		mode = modeId,
	})
end

local function tryStartGather(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local count = countValid(queues[modeId])
	if count < config.minPlayers then
		return
	end

	if gatherTokens[modeId] then
		return
	end

	gatherTokens[modeId] = true
	broadcastQueueState(modeId)

	local delay = config.gatherDelay
	if delay <= 0 then
		local players = getValidPlayers(queues[modeId], config.maxPlayers)
		startMatch(modeId, players)
		return
	end

	task.delay(delay, function()
		if not gatherTokens[modeId] then
			return
		end
		local players = getValidPlayers(queues[modeId], config.maxPlayers)
		if #players >= config.minPlayers then
			startMatch(modeId, players)
		else
			clearGather(modeId)
			broadcastQueueState(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end

	local config = getModeConfig(modeId)
	if not config or not queues[modeId] then
		return false, "invalid_mode"
	end

	if playerQueue[player] == modeId then
		Remotes.QueueState:FireClient(player, buildQueuePayload(modeId, player))
		return true
	end

	removeFromQueue(player, true)
	playerQueue[player] = modeId
	table.insert(queues[modeId], player)
	broadcastQueueState(modeId)
	tryStartGather(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	removeFromQueue(player, false)
	if gatherTokens[modeId] and countValid(queues[modeId]) < getModeConfig(modeId).minPlayers then
		clearGather(modeId)
		broadcastQueueState(modeId)
	end
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.cleanupPlayer(player)
	MatchmakingService.leaveQueue(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.cleanupPlayer(player)
end)

return MatchmakingService
