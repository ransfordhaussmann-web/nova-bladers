local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local HubService = require(script.Parent.HubService)
local MatchState = require(script.Parent.MatchState)

local MatchmakingService = {}

local remotes = nil
local matchReady = nil

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local ffaFillDeadline = nil
local onArenaFreeCallback = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromList(list, player)
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			table.remove(list, index)
			return true
		end
	end
	return false
end

local function clearFfaDeadlineIfEmpty()
	if #queues.ffa == 0 then
		ffaFillDeadline = nil
	end
end

local function getQueuePosition(modeId, player)
	for index, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function buildPlayerUpdate(player)
	local entry = playerEntry[player]
	if not entry then
		return nil
	end

	local modeId = entry.mode
	local modeConfig = getModeConfig(modeId)
	local total = #queues[modeId]
	local status = "waiting"

	if MatchState.isBusy() then
		status = "pending"
	elseif modeId == "ffa" and total >= modeConfig.minPlayers and ffaFillDeadline then
		status = "filling"
	end

	local fillSecondsLeft = nil
	if status == "filling" and ffaFillDeadline then
		fillSecondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		mode = modeId,
		modeLabel = modeConfig.label,
		position = getQueuePosition(modeId, player),
		total = total,
		minPlayers = modeConfig.minPlayers,
		maxPlayers = modeConfig.maxPlayers,
		status = status,
		fillSecondsLeft = fillSecondsLeft,
	}
end

function MatchmakingService.setOnArenaFree(callback)
	onArenaFreeCallback = callback
end

function MatchmakingService.notifyArenaFree()
	if onArenaFreeCallback then
		onArenaFreeCallback()
	end
end

function MatchmakingService.getPlayerUpdate(player)
	return buildPlayerUpdate(player)
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.leave(player)
	local entry = playerEntry[player]
	if not entry then
		return false
	end

	removeFromList(queues[entry.mode], player)
	playerEntry[player] = nil
	clearFfaDeadlineIfEmpty()
	return true
end

function MatchmakingService.join(player, modeId)
	if not isValidMode(modeId) then
		return false
	end

	MatchmakingService.leave(player)
	table.insert(queues[modeId], player)
	playerEntry[player] = {
		mode = modeId,
		joinedAt = os.clock(),
	}

	local modeConfig = getModeConfig(modeId)
	if modeId == "ffa" and #queues.ffa >= modeConfig.minPlayers and not ffaFillDeadline then
		ffaFillDeadline = os.clock() + modeConfig.fillTimeout
	end

	return true
end

local function takePlayers(modeId, count)
	local taken = {}
	for _ = 1, count do
		local nextPlayer = queues[modeId][1]
		if not nextPlayer then
			break
		end
		table.remove(queues[modeId], 1)
		playerEntry[nextPlayer] = nil
		table.insert(taken, nextPlayer)
	end
	clearFfaDeadlineIfEmpty()
	return taken
end

local function shouldStartMode(modeId)
	local modeConfig = getModeConfig(modeId)
	local total = #queues[modeId]

	if total < modeConfig.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if total >= modeConfig.maxPlayers then
			return true
		end
		if ffaFillDeadline and os.clock() >= ffaFillDeadline then
			return true
		end
		return false
	end

	return total >= modeConfig.maxPlayers
end

local function playersForMode(modeId)
	local modeConfig = getModeConfig(modeId)
	local total = #queues[modeId]
	local count = math.min(total, modeConfig.maxPlayers)
	return takePlayers(modeId, count)
end

function MatchmakingService.tryStartMatch()
	if MatchState.isBusy() then
		return nil
	end

	for _, modeId in MatchmakingConfig.QUEUE_PRIORITY do
		if shouldStartMode(modeId) then
			local players = playersForMode(modeId)
			if #players > 0 then
				return {
					mode = modeId,
					players = players,
				}
			end
		end
	end

	return nil
end

function MatchmakingService.getAllQueuedPlayers()
	local seen = {}
	local list = {}

	for _, modeId in { "training", "pvp", "ffa" } do
		for _, player in queues[modeId] do
			if not seen[player] then
				seen[player] = true
				table.insert(list, player)
			end
		end
	end

	return list
end

local function getAutoModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function resolveModeId(modeId)
	if typeof(modeId) == "string" and MatchmakingConfig.MODES[modeId] then
		return modeId
	end
	return getAutoModeId()
end

local function broadcastQueueUpdates()
	if not remotes then
		return
	end

	for _, player in MatchmakingService.getAllQueuedPlayers() do
		if player.Parent then
			local update = MatchmakingService.getPlayerUpdate(player)
			if update then
				remotes.QueueUpdate:FireClient(player, update)
			end
		end
	end
end

local function startReadyMatch(matchInfo)
	MatchState.setBusy(true)

	local readyPlayers = {}
	for _, player in matchInfo.players do
		if player.Parent and HubService.getPhase(player) == "hub" then
			HubService.leaveHubForArena(player)
			table.insert(readyPlayers, player)
		end
	end

	if #readyPlayers == 0 then
		MatchState.setBusy(false)
		return
	end

	for _, player in readyPlayers do
		remotes.QueueUpdate:FireClient(player, {
			mode = matchInfo.mode,
			status = "starting",
		})
	end

	matchReady:Fire(readyPlayers, matchInfo.mode)
end

local function processQueues()
	local matchInfo = MatchmakingService.tryStartMatch()
	if matchInfo then
		startReadyMatch(matchInfo)
	end
	broadcastQueueUpdates()
end

local function joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if MatchmakingService.isQueued(player) then
		return
	end

	local resolvedMode = resolveModeId(modeId)
	MatchmakingService.join(player, resolvedMode)
	processQueues()
end

local function leaveQueue(player)
	if MatchmakingService.leave(player) then
		remotes.QueueUpdate:FireClient(player, { status = "left" })
		processQueues()
	end
end

function MatchmakingService.start(remoteFolder, bindables)
	if remotes then
		return
	end

	remotes = remoteFolder
	matchReady = bindables.MatchReady

	MatchmakingService.setOnArenaFree(function()
		processQueues()
	end)

	HubService.registerMatchmaking({
		joinQueue = joinQueue,
		leaveQueue = leaveQueue,
	})

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if MatchmakingService.leave(player) then
			task.defer(processQueues)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			if not MatchState.isBusy() then
				processQueues()
			else
				broadcastQueueUpdates()
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
