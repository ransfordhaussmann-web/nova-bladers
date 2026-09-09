local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local onMatchReady = nil
local onQueueChanged = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function indexOfPlayer(queue, player)
	for i, queued in queue do
		if queued == player then
			return i
		end
	end
	return nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	local queue = getQueue(modeId)
	local index = indexOfPlayer(queue, player)
	if index then
		table.remove(queue, index)
	end
	playerQueue[player] = nil

	if modeId == "ffa" and #queue < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillToken += 1
	end

	return modeId
end

local function buildQueueStatus(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local required = mode.minPlayers
	local status = "waiting"

	if count >= required then
		status = MatchStateService.isArenaBusy() ? "pending" : "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		required = required,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function broadcastQueueUpdates()
	if not onQueueChanged then
		return
	end

	local seen = {}
	for _, modeId in { "training", "pvp", "ffa" } do
		for _, player in getQueue(modeId) do
			if not seen[player] and player.Parent then
				seen[player] = true
				local payload = buildQueueStatus(modeId)
				payload.inQueue = true
				payload.arenaBusy = MatchStateService.isArenaBusy()
				onQueueChanged(player, payload)
			end
		end
	end
end

local function notifyLeftQueue(player)
	if onQueueChanged and player.Parent then
		onQueueChanged(player, { inQueue = false })
	end
end

local function popPlayers(modeId, amount)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(amount, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates()
		return
	end

	local amount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, amount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		return
	end

	if modeId == "ffa" then
		ffaFillToken += 1
	end

	MatchStateService.setArenaBusy(true)
	broadcastQueueUpdates()

	if onMatchReady then
		onMatchReady(players, modeId)
	end
end

local function scheduleFfaFill()
	local mode = MatchmakingConfig.MODES.ffa
	local queue = getQueue("ffa")
	if #queue < mode.minPlayers then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(mode.fillTimeout, function()
		if token ~= ffaFillToken then
			return
		end
		if #getQueue("ffa") >= mode.minPlayers then
			startMatch("ffa")
		end
	end)
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			ffaFillToken += 1
			startMatch("ffa")
		else
			scheduleFfaFill()
		end
	else
		startMatch(modeId)
	end
end

function MatchmakingService.setHandlers(handlers)
	onMatchReady = handlers.onMatchReady
	onQueueChanged = handlers.onQueueChanged
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true, "already_queued"
		end
		removeFromQueue(player)
	end

	if #getQueue(modeId) >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	tryStartMatch(modeId)
	broadcastQueueUpdates()
	return true, "joined"
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	removeFromQueue(player)
	notifyLeftQueue(player)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.onArenaFreed()
	for _, modeId in { "training", "pvp", "ffa" } do
		tryStartMatch(modeId)
	end
	broadcastQueueUpdates()
end

function MatchmakingService.handlePlayerRemoving(player)
	if playerQueue[player] then
		removeFromQueue(player)
		broadcastQueueUpdates()
	end
end

MatchStateService.onArenaFreed(function()
	MatchmakingService.onArenaFreed()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.handlePlayerRemoving(player)
end)

return MatchmakingService
