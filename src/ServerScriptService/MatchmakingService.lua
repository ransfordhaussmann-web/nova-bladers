local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillStartedAt = nil
local remotes
local bindables
local hubService
local tickConnection

local function getMode(modeId)
	return MatchModes[modeId]
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueueList(player, modeId)
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			return true
		end
	end
	return false
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = getMode(entry.modeId)
	if not mode then
		return { inQueue = false }
	end

	local count = queueCount(entry.modeId)
	local needed = mode.minPlayers
	local status = "waiting"
	local statusText = string.format("%d / %d Spieler", count, needed)

	if GameMatchState.isArenaBusy() then
		status = "pending"
		statusText = "Arena belegt — warte..."
	elseif entry.modeId == "ffa" and count >= mode.minPlayers and count < mode.maxPlayers then
		local remaining = 0
		if ffaFillStartedAt then
			remaining = math.max(0, math.ceil(MatchmakingConfig.FFA_FILL_TIMEOUT - (os.clock() - ffaFillStartedAt)))
		end
		status = "waiting"
		statusText = string.format("%d / %d — Start in %ds", count, mode.maxPlayers, remaining)
	elseif count >= mode.minPlayers then
		status = "ready"
		statusText = "Match startet..."
	end

	return {
		inQueue = true,
		modeId = mode.id,
		modeLabel = mode.label,
		players = count,
		needed = needed,
		maxPlayers = mode.maxPlayers,
		status = status,
		statusText = statusText,
	}
end

local function sendQueueUpdate(player)
	if not remotes or not player.Parent then
		return
	end
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
end

local function resetFfaFillTimer()
	ffaFillStartedAt = nil
end

local function updateFfaFillTimer()
	local count = queueCount("ffa")
	local mode = MatchModes.ffa
	if count >= mode.minPlayers and count < mode.maxPlayers then
		if not ffaFillStartedAt then
			ffaFillStartedAt = os.clock()
		end
	else
		resetFfaFillTimer()
	end
end

local function clearPlayerQueue(player, notify)
	playerQueue[player] = nil
	if notify ~= false then
		if remotes and player.Parent then
			remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	removeFromQueueList(player, entry.modeId)
	clearPlayerQueue(player)
	updateFfaFillTimer()
	broadcastQueueUpdates()
end

local function takePlayers(modeId, amount)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(amount, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			table.insert(taken, nextPlayer)
			playerQueue[nextPlayer] = nil
		end
	end
	return taken
end

local function canStartMode(modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, 0
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return false, 0
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			return true, mode.maxPlayers
		end
		if ffaFillStartedAt and os.clock() - ffaFillStartedAt >= MatchmakingConfig.FFA_FILL_TIMEOUT then
			return true, count
		end
		return false, 0
	end

	return true, mode.maxPlayers
end

function MatchmakingService.tryStartMatches()
	if GameMatchState.isArenaBusy() then
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local canStart, takeCount = canStartMode(modeId)
		if canStart then
			local matchedPlayers = takePlayers(modeId, takeCount)
			if #matchedPlayers == 0 then
				return
			end

			if modeId == "ffa" then
				resetFfaFillTimer()
			end

			for _, matchedPlayer in matchedPlayers do
				if hubService and hubService.leaveHubForArena then
					hubService.leaveHubForArena(matchedPlayer)
				end
				if remotes and matchedPlayer.Parent then
					remotes.QueueUpdate:FireClient(matchedPlayer, { inQueue = false })
				end
			end

			broadcastQueueUpdates()
			bindables.MatchReady:Fire(matchedPlayers, modeId)
			return
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	updateFfaFillTimer()
	sendQueueUpdate(player)
	broadcastQueueUpdates()
	MatchmakingService.tryStartMatches()
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local modeId = "training"
	if count >= 3 then
		modeId = "ffa"
	elseif count == 2 then
		modeId = "pvp"
	end
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.start(newRemotes, newBindables, newHubService)
	remotes = newRemotes
	bindables = newBindables
	hubService = newHubService

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	GameMatchState.onArenaFree(function()
		MatchmakingService.tryStartMatches()
	end)

	if tickConnection then
		tickConnection:Disconnect()
	end

	tickConnection = game:GetService("RunService").Heartbeat:Connect(function()
		if not next(playerQueue) then
			return
		end

		local now = os.clock()
		if not MatchmakingService._lastTick or now - MatchmakingService._lastTick >= MatchmakingConfig.QUEUE_TICK_INTERVAL then
			MatchmakingService._lastTick = now
			updateFfaFillTimer()
			broadcastQueueUpdates()
			MatchmakingService.tryStartMatches()
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
