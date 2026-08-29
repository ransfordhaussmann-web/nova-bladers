--[[
	MatchmakingService — per-mode queues (Training / 1v1 / FFA).
	Forms matches when enough players are waiting and notifies GameManager.
]]

local Players = game:GetService("Players")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local MatchmakingService = {}

local MODE_ORDER = { "training", "pvp", "ffa" }

local MODE_REQUIREMENTS = {
	training = { min = 1, max = 1, label = "Training" },
	pvp = { min = 2, max = 2, label = "1v1 PvP" },
	ffa = { min = HubConfig.MATCHMAKING.FFA_MIN_PLAYERS, max = 8, label = "FFA" },
}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaWaitStarted = {}
local onMatchReady
local remotes

local function getRequirement(modeId)
	return MODE_REQUIREMENTS[modeId]
end

local function isValidMode(modeId)
	return getRequirement(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	ffaWaitStarted[player] = nil
end

local function buildQueueSnapshot(modeId)
	local queue = queues[modeId]
	local req = getRequirement(modeId)
	return {
		mode = modeId,
		label = req.label,
		waiting = #queue,
		required = req.min,
		players = {},
	}
end

local function sendQueueState(player)
	if not remotes or not remotes.QueueState then
		return
	end

	local modeId = playerQueue[player]
	if not modeId then
		remotes.QueueState:FireClient(player, {
			inQueue = false,
		})
		return
	end

	local queue = queues[modeId]
	local req = getRequirement(modeId)
	local position = 0
	local names = {}
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
		end
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	remotes.QueueState:FireClient(player, {
		inQueue = true,
		mode = modeId,
		label = req.label,
		position = position,
		waiting = #queue,
		required = req.min,
		players = names,
	})
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			sendQueueState(queuedPlayer)
		end
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local matched = {}
	for _ = 1, math.min(count, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			ffaWaitStarted[nextPlayer] = nil
			table.insert(matched, nextPlayer)
		end
	end
	return matched
end

local function tryStartMatch(modeId, options)
	options = options or {}
	local req = getRequirement(modeId)
	local queue = queues[modeId]
	local minPlayers = req.min
	if modeId == "ffa" and options.allowTwo then
		minPlayers = 2
	end

	if #queue < minPlayers then
		return
	end

	local take = minPlayers
	if modeId == "ffa" then
		take = math.min(#queue, req.max)
	elseif modeId == "pvp" then
		take = 2
	elseif modeId == "training" then
		take = 1
	end

	local matched = popPlayers(modeId, take)
	if #matched < minPlayers then
		for _, matchedPlayer in matched do
			table.insert(queue, matchedPlayer)
			playerQueue[matchedPlayer] = modeId
		end
		return
	end

	broadcastQueueUpdates(modeId)
	if onMatchReady then
		onMatchReady(matched, modeId)
	end
end

local function scheduleFfaFallback(player)
	if ffaWaitStarted[player] then
		return
	end
	ffaWaitStarted[player] = true

	local token = player
	task.delay(HubConfig.MATCHMAKING.FFA_START_WITH_TWO_AFTER, function()
		if playerQueue[player] ~= "ffa" or token ~= player or not player.Parent then
			return
		end

		local queue = queues.ffa
		if #queue < 2 then
			return
		end

		tryStartMatch("ffa", { allowTwo = true })
	end)
end

function MatchmakingService.configure(remoteFolder)
	remotes = remoteFolder
end

function MatchmakingService.onMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			sendQueueState(player)
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdates(modeId)
	sendQueueState(player)

	task.delay(HubConfig.MATCHMAKING.GATHER_DELAY, function()
		if playerQueue[player] ~= modeId then
			return
		end
		tryStartMatch(modeId)
		if modeId == "ffa" and playerQueue[player] == "ffa" then
			scheduleFfaFallback(player)
		end
	end)

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		sendQueueState(player)
		return false
	end

	removeFromQueue(player)
	broadcastQueueUpdates(modeId)
	sendQueueState(player)
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPreferredMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.getQueueSnapshot(modeId)
	if not isValidMode(modeId) then
		return nil
	end
	return buildQueueSnapshot(modeId)
end

function MatchmakingService.getAllSnapshots()
	local snapshots = {}
	for _, modeId in MODE_ORDER do
		snapshots[modeId] = buildQueueSnapshot(modeId)
	end
	return snapshots
end

Players.PlayerRemoving:Connect(function(player)
	local modeId = playerQueue[player]
	if modeId then
		removeFromQueue(player)
		broadcastQueueUpdates(modeId)
	end
end)

return MatchmakingService
