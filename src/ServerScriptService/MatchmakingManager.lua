--[[
	Per-mode matchmaking queues: training (1), pvp (2), ffa (3+).
	Starts matches via Bindables.StartMatch when thresholds are met.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MODE_REQUIREMENTS = {
	training = 1,
	pvp = 2,
	ffa = 3,
}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local soloTimers = {}

local MatchmakingManager = {}

local function isValidMode(modeId)
	return MODE_REQUIREMENTS[modeId] ~= nil
end

local function removeFromList(list, player)
	for i, p in list do
		if p == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

local function getQueueCounts()
	return {
		training = #queues.training,
		pvp = #queues.pvp,
		ffa = #queues.ffa,
	}
end

local function buildQueuePayload(forPlayer)
	local modeId = playerQueue[forPlayer]
	local counts = getQueueCounts()
	local required = modeId and MODE_REQUIREMENTS[modeId] or 0
	local inQueue = modeId and counts[modeId] or 0
	local position = 0

	if modeId then
		for i, p in queues[modeId] do
			if p == forPlayer then
				position = i
				break
			end
		end
	end

	return {
		modeId = modeId,
		position = position,
		inQueue = inQueue,
		required = required,
		counts = counts,
		requirements = MODE_REQUIREMENTS,
		soloDelay = HubConfig.QUEUE_SOLO_DELAY,
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function cancelSoloTimer(modeId)
	local token = soloTimers[modeId]
	if token then
		soloTimers[modeId] = nil
	end
	return token
end

local function tryStartMatch(modeId)
	local queue = queues[modeId]
	local required = MODE_REQUIREMENTS[modeId]
	if #queue < required then
		return false
	end

	local matched = {}
	for _ = 1, required do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matched, player)
		end
	end

	if #matched < required then
		for _, player in matched do
			table.insert(queue, 1, player)
			playerQueue[player] = modeId
		end
		return false
	end

	cancelSoloTimer(modeId)
	Bindables.StartMatch:Fire({ players = matched, mode = modeId })
	broadcastQueueUpdate()
	return true
end

local function scheduleSoloStart(modeId)
	if modeId ~= "training" then
		return
	end
	if soloTimers[modeId] then
		return
	end

	local token = {}
	soloTimers[modeId] = token
	task.delay(HubConfig.QUEUE_SOLO_DELAY, function()
		if soloTimers[modeId] ~= token then
			return
		end
		soloTimers[modeId] = nil
		if #queues.training >= 1 then
			tryStartMatch("training")
		end
	end)
end

function MatchmakingManager.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		return true
	end

	MatchmakingManager.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate()

	if modeId == "training" and #queues.training == 1 then
		scheduleSoloStart("training")
	elseif #queues[modeId] >= MODE_REQUIREMENTS[modeId] then
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingManager.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromList(queues[modeId], player)
	playerQueue[player] = nil

	if modeId == "training" and #queues.training == 0 then
		cancelSoloTimer("training")
	end

	broadcastQueueUpdate()
end

function MatchmakingManager.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingManager.sendQueueState(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

function MatchmakingManager.init()
	Remotes.JoinQueue.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingManager.joinQueue(player, modeId)
	end)

	Remotes.LeaveQueue.OnServerEvent:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)
end

return MatchmakingManager
