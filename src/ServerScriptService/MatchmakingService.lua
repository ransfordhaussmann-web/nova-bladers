--[[
	MatchmakingService — mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReadyBindable
local leaveHubForArena
local getRecommendedModeId
local getPlayerPhase

local queues = {}
local playerEntry = {}
local pendingMatch = nil
local fillTimers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueuedNames(modeId)
	local names = {}
	for _, entry in getQueue(modeId) do
		if entry.player.Parent then
			table.insert(names, entry.player.Name)
		end
	end
	return names
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		fillTimers[modeId] = nil
	end
end

local function buildUpdatePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local fillTimer = fillTimers[entry.modeId]

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		status = entry.status,
		currentPlayers = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeLeft = fillTimer and math.max(0, math.ceil(fillTimer.endsAt - os.clock())) or nil,
		queuedNames = getQueuedNames(entry.modeId),
	}
end

local function broadcastQueue(modeId)
	for _, entry in getQueue(modeId) do
		local player = entry.player
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
		end
	end
end

local function removeFromPending(player)
	if not pendingMatch then
		return
	end
	local filtered = {}
	for _, p in pendingMatch.players do
		if p ~= player then
			table.insert(filtered, p)
		end
	end
	if #filtered == 0 then
		pendingMatch = nil
		return
	end

	local mode = MatchModes.get(pendingMatch.modeId)
	if mode and #filtered < mode.minPlayers then
		pendingMatch = nil
		for _, p in filtered do
			local record = playerEntry[p]
			if record then
				record.status = "waiting"
				remotes.QueueUpdate:FireClient(p, buildUpdatePayload(p))
			end
		end
	else
		pendingMatch.players = filtered
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		removeFromPending(player)
		return
	end

	local modeId = entry.modeId
	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued.player == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
	removeFromPending(player)
	clearFillTimer(modeId)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if mode and #getQueue(modeId) >= mode.minPlayers then
		tryStartMode(modeId)
	end
end

local function peekPlayers(modeId, count)
	local queue = getQueue(modeId)
	local players = {}
	for i = 1, math.min(count, #queue) do
		local queued = queue[i]
		if queued and queued.player.Parent then
			table.insert(players, queued.player)
		end
	end
	return players
end

local function launchMatch(playerList, modeId)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy()
	for _, player in playerList do
		local entry = playerEntry[player]
		if entry then
			entry.modeId = modeId
		end
		removeFromQueue(player)
	end

	if leaveHubForArena then
		for _, player in playerList do
			if player.Parent then
				leaveHubForArena(player)
			end
		end
	end

	matchReadyBindable:Fire(playerList, modeId)
end

local function beginQueueMatch(modeId, count)
	local players = peekPlayers(modeId, count)
	if #players == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			players = players,
			modeId = modeId,
		}
		for _, player in players do
			local record = playerEntry[player]
			if record then
				record.status = "pending"
				remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
			end
		end
		return
	end

	launchMatch(players, modeId)
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if mode.instantStart then
		beginQueueMatch(modeId, mode.minPlayers)
		return
	end

	if #queue >= mode.maxPlayers then
		beginQueueMatch(modeId, mode.maxPlayers)
		return
	end

	if modeId == "ffa" and not fillTimers[modeId] then
		for _, queued in queue do
			local record = playerEntry[queued.player]
			if record then
				record.status = "filling"
			end
		end
		local endsAt = os.clock() + (mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT)
		fillTimers[modeId] = { endsAt = endsAt }
		broadcastQueue(modeId)
		task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			if fillTimers[modeId] and fillTimers[modeId].endsAt == endsAt then
				clearFillTimer(modeId)
				local current = getQueue(modeId)
				if #current >= mode.minPlayers then
					beginQueueMatch(modeId, #current)
				end
			end
		end)
	end

	if modeId == "pvp" and #queue >= mode.minPlayers then
		beginQueueMatch(modeId, mode.minPlayers)
	end
end

local function processPending()
	if pendingMatch and not MatchStateService.isArenaBusy() then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.players, match.modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if getPlayerPhase and getPlayerPhase(player) ~= "hub" then
		return
	end

	table.insert(getQueue(modeId), { player = player })
	playerEntry[player] = {
		modeId = modeId,
		status = "waiting",
	}

	remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	broadcastQueue(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.joinRecommended(player)
	local modeId = getRecommendedModeId and getRecommendedModeId() or "training"
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.getPlayerQueue(player)
	return playerEntry[player]
end

function MatchmakingService.init(options)
	remotes = options.remotes
	matchReadyBindable = options.matchReadyBindable
	leaveHubForArena = options.leaveHubForArena
	getRecommendedModeId = options.getRecommendedModeId
	getPlayerPhase = options.getPhase

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinRecommended(player)
		end
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if pendingMatch then
			local filtered = {}
			for _, p in pendingMatch.players do
				if p ~= player then
					table.insert(filtered, p)
				end
			end
			if #filtered == 0 then
				pendingMatch = nil
			else
				pendingMatch.players = filtered
			end
		end
	end)

	MatchStateService.onArenaIdle(processPending)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for modeId in pairs(queues) do
				if #getQueue(modeId) > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
