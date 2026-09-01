--[[
	MatchQueueService — mode-based matchmaking queue for Nova Bladers.
	Players join a queue (training / pvp / ffa) and matches start when
	the minimum player count is met or a timeout expires.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueUpdate = Remotes.QueueUpdate
local MatchQueueReady = Bindables.MatchQueueReady

local MatchQueueService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local playerMode = {}
local queueTokens = {
	training = 0,
	pvp = 0,
	ffa = 0,
}

local function getModeConfig(modeId)
	return HubConfig.QUEUE_MODES[modeId] or HubConfig.QUEUE_MODES.training
end

local function resolveModeForCount(modeId, count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildStatusPayload(modeId)
	local queue = queues[modeId]
	local config = getModeConfig(modeId)
	return {
		modeId = modeId,
		modeLabel = config.label,
		count = #queue,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
	}
end

local function broadcastQueue(modeId)
	local status = buildStatusPayload(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			local position = 1
			for i, p in ipairs(queues[modeId]) do
				if p == player then
					position = i
					break
				end
			end
			QueueUpdate:FireClient(player, {
				inQueue = true,
				position = position,
				count = status.count,
				needed = status.needed,
				modeId = modeId,
				modeLabel = status.modeLabel,
			})
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	queueTokens[modeId] += 1

	if player.Parent then
		QueueUpdate:FireClient(player, { inQueue = false })
	end

	broadcastQueue(modeId)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
			QueueUpdate:FireClient(player, { inQueue = false, matchFound = true })
		end
	end
	broadcastQueue(modeId)
	return picked
end

local function startMatch(modeId, token)
	local queue = queues[modeId]
	if #queue == 0 then
		return
	end

	local config = getModeConfig(modeId)
	local actualMode = resolveModeForCount(modeId, #queue)
	local takeCount = #queue

	if actualMode == "training" then
		takeCount = 1
	elseif actualMode == "pvp" then
		takeCount = math.min(2, #queue)
	elseif actualMode == "ffa" then
		takeCount = math.min(config.maxPlayers, #queue)
	end

	local players = popPlayers(modeId, takeCount)
	if #players == 0 then
		return
	end

	local finalMode = resolveModeForCount(modeId, #players)
	MatchQueueReady:Fire(players, finalMode)
end

local function scheduleQueueTick(modeId)
	queueTokens[modeId] += 1
	local token = queueTokens[modeId]
	local config = getModeConfig(modeId)

	task.delay(config.timeout, function()
		if token ~= queueTokens[modeId] then
			return
		end
		if #queues[modeId] == 0 then
			return
		end

		local count = #queues[modeId]
		if count >= config.minPlayers then
			startMatch(modeId, token)
		elseif count > 0 then
			local fallback = resolveModeForCount(modeId, count)
			if fallback == "training" or (fallback == "pvp" and count >= 2) then
				startMatch(modeId, token)
			end
		end
	end)
end

function MatchQueueService.setPreferredMode(player, modeId)
	if HubConfig.QUEUE_MODES[modeId] then
		playerMode[player] = modeId
	end
end

function MatchQueueService.getPreferredMode(player)
	return playerMode[player] or "training"
end

function MatchQueueService.join(player, modeId)
	modeId = modeId or MatchQueueService.getPreferredMode(player)
	if not HubConfig.QUEUE_MODES[modeId] then
		modeId = "training"
	end

	if playerQueue[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	local config = getModeConfig(modeId)
	QueueUpdate:FireClient(player, {
		inQueue = true,
		position = #queues[modeId],
		count = #queues[modeId],
		needed = config.minPlayers,
		modeId = modeId,
		modeLabel = config.label,
	})

	broadcastQueue(modeId)

	if #queues[modeId] >= config.minPlayers then
		startMatch(modeId, queueTokens[modeId])
	else
		if #queues[modeId] == 1 then
			scheduleQueueTick(modeId)
		end
	end
end

function MatchQueueService.leave(player)
	removeFromQueue(player)
end

function MatchQueueService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchQueueService.cleanup(player)
	removeFromQueue(player)
	playerMode[player] = nil
end

Players.PlayerRemoving:Connect(function(player)
	MatchQueueService.cleanup(player)
end)

return MatchQueueService
