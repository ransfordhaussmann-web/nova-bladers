--[[
	MatchmakingManager — per-mode queues (training / pvp / ffa).
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local MatchmakingManager = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local readyHandlers = {}
local queueUpdateRemote = nil

local function isValidMode(mode)
	return HubConfig.QUEUE_REQUIRED[mode] ~= nil
end

local function removeFromQueue(player, silent)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local queue = queues[entry.mode]
	for i, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil

	if not silent then
		MatchmakingManager.broadcastAll()
	end

	return entry.mode
end

local function getQueueSnapshot(mode)
	local queue = queues[mode]
	local names = {}
	for _, queuedPlayer in ipairs(queue) do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	return {
		mode = mode,
		modeLabel = HubConfig.QUEUE_LABELS[mode],
		count = #names,
		required = HubConfig.QUEUE_REQUIRED[mode],
		players = names,
	}
end

function MatchmakingManager.configure(remotes)
	queueUpdateRemote = remotes.QueueUpdate
end

function MatchmakingManager.onMatchReady(handler)
	table.insert(readyHandlers, handler)
end

function MatchmakingManager.getPosition(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local queue = queues[entry.mode]
	for index, queuedPlayer in ipairs(queue) do
		if queuedPlayer == player then
			return index
		end
	end

	return nil
end

function MatchmakingManager.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingManager.broadcastAll()
	if not queueUpdateRemote then
		return
	end

	for _, player in Players:GetPlayers() do
		local entry = playerEntry[player]
		local waiting = entry and #queues[entry.mode] or 0

		queueUpdateRemote:FireClient(player, {
			inQueue = entry ~= nil,
			mode = entry and entry.mode,
			modeLabel = entry and HubConfig.QUEUE_LABELS[entry.mode],
			position = entry and MatchmakingManager.getPosition(player),
			required = entry and HubConfig.QUEUE_REQUIRED[entry.mode],
			waiting = waiting,
			queues = {
				training = getQueueSnapshot("training"),
				pvp = getQueueSnapshot("pvp"),
				ffa = getQueueSnapshot("ffa"),
			},
		})
	end
end

function MatchmakingManager.join(player, mode)
	if not isValidMode(mode) or not player.Parent then
		return false
	end

	if playerEntry[player] then
		if playerEntry[player].mode == mode then
			return true
		end
		removeFromQueue(player, true)
	end

	table.insert(queues[mode], player)
	playerEntry[player] = {
		mode = mode,
		joinedAt = os.clock(),
	}

	MatchmakingManager.broadcastAll()
	MatchmakingManager.tryPopMatches()
	return true
end

function MatchmakingManager.leave(player)
	if not playerEntry[player] then
		return false
	end

	removeFromQueue(player)
	return true
end

function MatchmakingManager.tryPopMatches()
	for mode, required in pairs(HubConfig.QUEUE_REQUIRED) do
		local queue = queues[mode]
		while #queue >= required do
			local matchPlayers = {}
			for _ = 1, required do
				table.insert(matchPlayers, table.remove(queue, 1))
			end

			for _, matchedPlayer in matchPlayers do
				playerEntry[matchedPlayer] = nil
			end

			for _, handler in readyHandlers do
				handler(matchPlayers, mode)
			end
		end
	end

	MatchmakingManager.broadcastAll()
end

function MatchmakingManager.cleanupPlayer(player)
	removeFromQueue(player, true)
end

return MatchmakingManager
