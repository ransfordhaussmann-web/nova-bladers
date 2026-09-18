local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady
local HubService

local queues = {}
local playerQueue = {}
local fillTimers = {}
local fillStartedAt = {}

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		task.cancel(fillTimers[modeId])
		fillTimers[modeId] = nil
	end
	fillStartedAt[modeId] = nil
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if #queue == 0 then
		clearFillTimer(modeId)
	end
end

local function getQueueStatus(modeId)
	local mode = getMode(modeId)
	if not mode then
		return "waiting", "Unbekannter Modus"
	end

	local queue = ensureQueue(modeId)
	local count = #queue
	local needed = mode.maxPlayers

	if MatchStateService.isBusy() then
		return "pending", string.format("Arena belegt — %d in Warteschlange", count)
	end

	if count >= mode.maxPlayers then
		return "starting", "Match startet..."
	end

	if mode.id == "training" and count >= 1 then
		return "starting", "Match startet..."
	end

	if mode.id == "pvp" and count >= 2 then
		return "starting", "Match startet..."
	end

	if mode.id == "ffa" then
		if count >= mode.maxPlayers then
			return "starting", "Match startet..."
		end

		if count >= mode.minPlayers and fillStartedAt[modeId] then
			local elapsed = os.clock() - fillStartedAt[modeId]
			local remaining = math.max(0, math.ceil(MatchmakingConfig.FFA_FILL_TIMEOUT - elapsed))
			return "waiting", string.format("FFA (%d/%d) — Start in %ds", count, mode.maxPlayers, remaining)
		end

		return "waiting", string.format("FFA (%d/%d) — warte auf Spieler", count, mode.maxPlayers)
	end

	return "waiting", string.format("%s (%d/%d)", mode.label, count, needed)
end

local function buildUpdatePayload(modeId, player)
	local status, message = getQueueStatus(modeId)
	local mode = getMode(modeId)
	local queue = ensureQueue(modeId)
	local payload = {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #queue,
		needed = mode and mode.maxPlayers or 0,
		status = status,
		message = message,
		inQueue = playerQueue[player] == modeId,
	}

	if modeId == "ffa" and fillStartedAt[modeId] and status == "waiting" then
		local elapsed = os.clock() - fillStartedAt[modeId]
		payload.secondsLeft = math.max(0, math.ceil(MatchmakingConfig.FFA_FILL_TIMEOUT - elapsed))
	end

	return payload
end

local function broadcastQueueUpdate(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode or MatchStateService.isBusy() then
		return false
	end

	local queue = ensureQueue(modeId)
	local count = #queue
	local shouldStart = false

	if mode.id == "training" and count >= 1 then
		shouldStart = true
	elseif mode.id == "pvp" and count >= 2 then
		shouldStart = true
	elseif mode.id == "ffa" then
		if count >= mode.maxPlayers then
			shouldStart = true
		elseif count >= mode.minPlayers and fillStartedAt[modeId] then
			local elapsed = os.clock() - fillStartedAt[modeId]
			if elapsed >= MatchmakingConfig.FFA_FILL_TIMEOUT then
				shouldStart = true
			end
		end
	end

	if not shouldStart then
		return false
	end

	local matchPlayers = {}
	for i = 1, math.min(count, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	clearFillTimer(modeId)
	broadcastQueueUpdate(modeId)

	for _, player in matchPlayers do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end

	for _, player in matchPlayers do
		if player.Parent and HubService.leaveHubForMatch then
			HubService.leaveHubForMatch(player)
		end
	end

	MatchReady:Fire({
		mode = modeId,
		players = matchPlayers,
	})

	return true
end

local function maybeStartFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or mode.id ~= "ffa" then
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		clearFillTimer(modeId)
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillStartedAt[modeId] = os.clock()
	fillTimers[modeId] = task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	broadcastQueueUpdate(modeId)
	maybeStartFillTimer(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = getMode(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerQueue[player] = modeId

	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	onQueueChanged(modeId)
end

function MatchmakingService.onMatchEnded()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
		maybeStartFillTimer(modeId)
		tryStartMatch(modeId)
	end
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.init(deps)
	Remotes = deps.Remotes
	MatchReady = deps.MatchReady
	HubService = deps.HubService

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removeFromQueue(player)
			onQueueChanged(modeId)
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
