--[[
	MatchmakingQueue — mode-specific queues (Training / 1v1 / FFA).
	Players join via hub mode pads or arena portal; matches pop when ready or on timeout.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchmakingQueue = {}

local QUEUE_MODES = HubConfig.QUEUE_MODES

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local onMatchReady = nil

local function getModeConfig(modeId)
	return QUEUE_MODES[modeId] or QUEUE_MODES.training
end

local function countQueue(modeId)
	return #queues[modeId]
end

local function buildStatusFor(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local modeId = entry.modeId
	local cfg = getModeConfig(modeId)
	local count = countQueue(modeId)

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = cfg.label,
		count = count,
		needed = cfg.minPlayers,
		waitTime = math.floor(os.clock() - entry.joinedAt),
	}
end

local function broadcastQueueUpdate()
	local statusByMode = {}
	for modeId in pairs(queues) do
		local cfg = getModeConfig(modeId)
		statusByMode[modeId] = {
			count = countQueue(modeId),
			needed = cfg.minPlayers,
			label = cfg.label,
		}
	end

	for player in pairs(playerEntry) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildStatusFor(player), statusByMode)
		end
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local list = queues[entry.modeId]
	for i, queued in list do
		if queued.player == player then
			table.remove(list, i)
			break
		end
	end

	playerEntry[player] = nil
end

function MatchmakingQueue.setMatchReadyCallback(callback)
	onMatchReady = callback
end

function MatchmakingQueue.join(player, modeId)
	if not queues[modeId] then
		modeId = "training"
	end

	MatchmakingQueue.leave(player)

	table.insert(queues[modeId], {
		player = player,
		joinedAt = os.clock(),
	})
	playerEntry[player] = { modeId = modeId, joinedAt = os.clock() }

	broadcastQueueUpdate()
	MatchmakingQueue.tryStartMatches()
end

function MatchmakingQueue.leave(player)
	if not playerEntry[player] then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false }, {})
	broadcastQueueUpdate()
end

function MatchmakingQueue.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingQueue.getMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId
end

local function resolveModeForPop(modeId, players)
	local cfg = getModeConfig(modeId)
	local count = #players

	if count >= cfg.minPlayers then
		return modeId, players
	end

	if modeId == "ffa" and count >= QUEUE_MODES.pvp.minPlayers then
		return "pvp", players
	end

	if count >= 1 then
		return "training", { players[1] }
	end

	return nil, nil
end

local function popPlayers(modeId, amount)
	local list = queues[modeId]
	local popped = {}
	for _ = 1, math.min(amount, #list) do
		local entry = table.remove(list, 1)
		if entry and entry.player.Parent then
			playerEntry[entry.player] = nil
			table.insert(popped, entry.player)
		end
	end
	return popped
end

function MatchmakingQueue.tryStartMatches()
	for modeId, list in pairs(queues) do
		if #list == 0 then
			-- skip empty queue
		else
		local cfg = getModeConfig(modeId)
		local ready = false
		local popCount = cfg.maxPlayers

		if #list >= cfg.minPlayers then
			ready = true
			popCount = math.min(#list, cfg.maxPlayers)
		elseif cfg.timeout > 0 then
			local oldest = list[1]
			if oldest and (os.clock() - oldest.joinedAt) >= cfg.timeout then
				ready = true
				popCount = #list
			end
		elseif modeId == "training" and #list >= 1 then
			ready = true
			popCount = 1
		end

		if ready then
			local players = popPlayers(modeId, popCount)
			local resolvedMode, matchPlayers = resolveModeForPop(modeId, players)
			if resolvedMode and matchPlayers and #matchPlayers > 0 and onMatchReady then
				broadcastQueueUpdate()
				onMatchReady(resolvedMode, matchPlayers)
				return
			end
		end
		end
	end
end

function MatchmakingQueue.clearPlayers(playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end
	broadcastQueueUpdate()
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.leave(player)
end)

task.spawn(function()
	while true do
		task.wait(1)
		MatchmakingQueue.tryStartMatches()
	end
end)

return MatchmakingQueue
