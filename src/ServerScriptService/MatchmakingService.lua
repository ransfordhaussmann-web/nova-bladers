local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local remotes
local bindables

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local fillTokens = {}

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end
end

local function getValidMode(modeId)
	if typeof(modeId) ~= "string" then
		return nil
	end
	return MatchmakingConfig.getMode(modeId)
end

local function isPlayerAvailable(player)
	return player.Parent and HubService.getPhase(player) == "hub" and not playerQueue[player]
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end

	local queue = queues[modeId]
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		modeId = modeId,
		label = mode.label,
		status = status or "waiting",
		position = position,
		total = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for index, player in queue do
		if player.Parent then
			local payload = buildQueuePayload(player, modeId, "waiting")
			payload.position = index
			remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function notifyPlayer(player, modeId, status)
	if not player.Parent then
		return
	end
	local payload = buildQueuePayload(player, modeId, status)
	if payload then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function clearPlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if fillTokens[modeId] then
		fillTokens[modeId] += 1
	end

	broadcastQueueUpdate(modeId)
end

local function removePendingPlayers(players)
	if not pendingMatch then
		return
	end

	local removeSet = {}
	for _, player in players do
		removeSet[player] = true
	end

	local filtered = {}
	for _, player in pendingMatch.players do
		if not removeSet[player] then
			table.insert(filtered, player)
		end
	end

	if #filtered == 0 then
		pendingMatch = nil
	else
		pendingMatch.players = filtered
	end
end

local function startMatch(playerList, modeId)
	for _, player in playerList do
		playerQueue[player] = nil
		HubService.enterArenaPhase(player)
	end

	for modeKey, queue in queues do
		local changed = false
		for index = #queue, 1, -1 do
			local queuedPlayer = queue[index]
			local inMatch = false
			for _, matchPlayer in playerList do
				if matchPlayer == queuedPlayer then
					inMatch = true
					break
				end
			end
			if inMatch then
				table.remove(queue, index)
				changed = true
			end
		end
		if changed then
			broadcastQueueUpdate(modeKey)
		end
	end

	bindables.MatchReady:Fire(playerList, modeId)
end

local function tryLaunchMatch(modeId, playerList)
	local valid = {}
	for _, player in playerList do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(valid, player)
		end
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or #valid < mode.minPlayers then
		return false
	end

	if #valid > mode.maxPlayers then
		local trimmed = {}
		for index = 1, mode.maxPlayers do
			trimmed[index] = valid[index]
		end
		valid = trimmed
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = valid,
		}
		for _, player in valid do
			notifyPlayer(player, modeId, "pending")
		end
		return true
	end

	startMatch(valid, modeId)
	return true
end

local function cancelFillTimer(modeId)
	if fillTokens[modeId] then
		fillTokens[modeId] += 1
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = (fillTokens[modeId] or 0) + 1
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end

		local queue = queues[modeId]
		if #queue < mode.minPlayers then
			return
		end

		tryLaunchMatch(modeId, queue)
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	if not mode or #queue == 0 then
		return
	end

	if mode.maxPlayers > 0 and #queue >= mode.maxPlayers then
		cancelFillTimer(modeId)
		tryLaunchMatch(modeId, queue)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout then
			if #queue == mode.minPlayers then
				scheduleFillTimer(modeId)
			end
		else
			tryLaunchMatch(modeId, queue)
		end
	end
end

function MatchmakingService.init(remotesFolder, bindablesFolder)
	remotes = remotesFolder
	bindables = bindablesFolder
	initQueues()

	MatchStateService.onArenaFree(function()
		if pendingMatch then
			local match = pendingMatch
			pendingMatch = nil
			tryLaunchMatch(match.modeId, match.players)
		end
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getValidMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end
	if not isPlayerAvailable(player) then
		return false, "unavailable"
	end
	if MatchStateService.isArenaBusy() and mode.minPlayers == 1 then
		return false, "arena_busy"
	end

	clearPlayerFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue, player)
	playerQueue[player] = modeId

	notifyPlayer(player, modeId, "waiting")
	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	clearPlayerFromQueue(player)
	removePendingPlayers({ player })
	remotes.QueueUpdate:FireClient(player, { status = "idle" })
	return true
end

function MatchmakingService.getRecommendedMode()
	return MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
end

function MatchmakingService.onPlayerRemoving(player)
	clearPlayerFromQueue(player)
	removePendingPlayers({ player })
end

return MatchmakingService
