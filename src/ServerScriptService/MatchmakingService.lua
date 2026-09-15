local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local remotes = nil
local matchReadyEvent = nil
local getSuggestedMode = nil
local getPlayerPhase = nil

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {
			players = {},
			fillDeadline = nil,
		}
	end
	return queues[modeId]
end

local function removeFromQueueList(queue, player)
	for i, queued in queue.players do
		if queued == player then
			table.remove(queue.players, i)
			return true
		end
	end
	return false
end

local function queueContains(queue, player)
	for _, queued in queue.players do
		if queued == player then
			return true
		end
	end
	return false
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	local count = #queue.players
	local maxPlayers = mode.maxPlayers
	local minPlayers = mode.minPlayers
	local arenaBusy = MatchStateService.isArenaBusy()

	local status = "waiting"
	if arenaBusy then
		status = "pending"
	elseif count >= maxPlayers then
		status = "ready"
	elseif modeId == "ffa" and count >= minPlayers and queue.fillDeadline then
		status = "filling"
	elseif count >= minPlayers then
		status = "ready"
	end

	local secondsLeft = nil
	if queue.fillDeadline then
		secondsLeft = math.max(0, math.ceil(queue.fillDeadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = minPlayers,
		maxPlayers = maxPlayers,
		status = status,
		arenaBusy = arenaBusy,
		secondsLeft = secondsLeft,
		inQueue = queueContains(queue, player),
	}
end

local function broadcastQueue(modeId)
	local queue = ensureQueue(modeId)
	for _, player in queue.players do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in pairs(queues) do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local queue = ensureQueue(modeId)
	queue.fillDeadline = nil
end

local function popPlayers(modeId, count)
	local queue = ensureQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue.players) do
		local player = table.remove(queue.players, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	clearFillTimer(modeId)
	return picked
end

local function fireMatchReady(modeId, playerList)
	for _, player in playerList do
		playerQueue[player] = nil
	end
	matchReadyEvent:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isArenaBusy() then
		return
	end

	local queue = ensureQueue(modeId)
	local count = #queue.players
	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		local players = popPlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			fireMatchReady(modeId, players)
		end
		return
	end

	if modeId == "ffa" then
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			local players = popPlayers(modeId, count)
			if #players >= mode.minPlayers then
				fireMatchReady(modeId, players)
			end
		end
		return
	end

	if count >= mode.minPlayers then
		local players = popPlayers(modeId, mode.minPlayers)
		if #players >= mode.minPlayers then
			fireMatchReady(modeId, players)
		end
	end
end

local function tryStartAllModes()
	for modeId in pairs(queues) do
		tryStartMode(modeId)
	end
end

local function scheduleFfaFill(modeId)
	local mode = MatchModes.get(modeId)
	local queue = ensureQueue(modeId)
	if #queue.players < mode.minPlayers or queue.fillDeadline then
		return
	end

	queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTokens[modeId] ~= token then
			return
		end
		tryStartMode(modeId)
		broadcastQueue(modeId)
	end)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = ensureQueue(modeId)
	removeFromQueueList(queue, player)

	if modeId == "ffa" and #queue.players < MatchModes.get("ffa").minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if getPlayerPhase and getPlayerPhase(player) == "arena" then
		return false, "in_match"
	end

	if playerQueue[player] == modeId then
		return true, "already_queued"
	end

	MatchmakingService.leaveQueue(player)

	local queue = ensureQueue(modeId)
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	if modeId == "ffa" and #queue.players >= mode.minPlayers then
		scheduleFfaFill(modeId)
	end

	broadcastQueue(modeId)

	if not MatchStateService.isArenaBusy() then
		tryStartMode(modeId)
	end

	return true, "joined"
end

function MatchmakingService.joinQuickMatch(player)
	local modeId = getSuggestedMode and getSuggestedMode() or "training"
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.start(deps)
	remotes = deps.remotes
	matchReadyEvent = deps.matchReadyEvent
	getSuggestedMode = deps.getSuggestedMode
	getPlayerPhase = deps.getPlayerPhase

	MatchStateService.onArenaFreed(function()
		tryStartAllModes()
		broadcastAllQueues()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId, queue in pairs(queues) do
				if queue.fillDeadline and os.clock() >= queue.fillDeadline then
					tryStartMode(modeId)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
