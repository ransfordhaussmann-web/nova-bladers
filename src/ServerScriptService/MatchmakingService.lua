--[[
	MatchmakingService — per-mode queues with fill timeout and arena-busy pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local fillTimers = {}
local pendingStarts = {}

for modeId in pairs(MatchmakingConfig.QUEUE_MODES) do
	queues[modeId] = {}
end

local function getModeConfig(modeId)
	return MatchmakingConfig.QUEUE_MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil

	local config = getModeConfig(modeId)
	if queueCount(modeId) < config.minPlayers then
		pendingStarts[modeId] = nil
		MatchmakingService.cancelFillTimer(modeId)
	end

	MatchmakingService.broadcastMode(modeId)
end

function MatchmakingService.cancelFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		task.cancel(timer)
		fillTimers[modeId] = nil
	end
end

local function buildUpdatePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local modeId = entry.modeId
	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	local needed = math.max(0, config.minPlayers - count)
	local status = entry.status or "waiting"

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		players = count,
		needed = needed,
		maxPlayers = config.maxPlayers,
		status = status,
		fillSecondsLeft = entry.fillSecondsLeft,
	}
end

function MatchmakingService.sendUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	end
end

function MatchmakingService.broadcastMode(modeId)
	for player, entry in pairs(playerEntry) do
		if entry.modeId == modeId and player.Parent then
			MatchmakingService.sendUpdate(player)
		end
	end
end

local function markModePending(modeId)
	for _, player in queues[modeId] do
		local entry = playerEntry[player]
		if entry then
			entry.status = "pending"
			MatchmakingService.sendUpdate(player)
		end
	end
end

local function popPlayersForMatch(modeId)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, config.maxPlayers)
	local matchPlayers = {}

	for i = 1, count do
		table.insert(matchPlayers, queue[1])
		playerEntry[queue[1]] = nil
		table.remove(queue, 1)
	end

	MatchmakingService.cancelFillTimer(modeId)
	pendingStarts[modeId] = nil
	MatchmakingService.broadcastMode(modeId)

	return matchPlayers
end

local function launchMatch(modeId)
	if MatchStateService.isBusy() then
		pendingStarts[modeId] = true
		markModePending(modeId)
		return
	end

	local config = getModeConfig(modeId)
	if queueCount(modeId) < config.minPlayers then
		return
	end

	local matchPlayers = popPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	MatchStateService.setBusy(true)

	for _, player in matchPlayers do
		if player.Parent and HubService.getPhase(player) ~= "arena" then
			HubService.leaveHubForArena(player)
		end
	end

	MatchReady:Fire(matchPlayers, modeId)
end

local function shouldStartNow(modeId)
	local config = getModeConfig(modeId)
	local count = queueCount(modeId)

	if count < config.minPlayers then
		return false
	end

	if modeId == "ffa" then
		return count >= config.maxPlayers
	end

	return count >= config.maxPlayers
end

local function startFillTimer(modeId)
	if fillTimers[modeId] then
		return
	end

	local config = getModeConfig(modeId)
	local timeout = config.fillTimeout or MatchmakingConfig.FILL_TIMEOUT
	local endsAt = os.clock() + timeout

	for _, player in queues[modeId] do
		local entry = playerEntry[player]
		if entry then
			entry.fillSecondsLeft = timeout
			entry.status = "waiting"
		end
	end
	MatchmakingService.broadcastMode(modeId)

	fillTimers[modeId] = task.spawn(function()
		while os.clock() < endsAt do
			local remaining = math.ceil(endsAt - os.clock())
			for _, player in queues[modeId] do
				local entry = playerEntry[player]
				if entry then
					entry.fillSecondsLeft = remaining
				end
			end
			MatchmakingService.broadcastMode(modeId)
			task.wait(1)
		end

		fillTimers[modeId] = nil
		for _, player in queues[modeId] do
			local entry = playerEntry[player]
			if entry then
				entry.fillSecondsLeft = nil
			end
		end

		if queueCount(modeId) >= getModeConfig(modeId).minPlayers then
			launchMatch(modeId)
		end
	end)
end

function MatchmakingService.evaluateMode(modeId)
	if pendingStarts[modeId] or MatchStateService.isBusy() then
		if queueCount(modeId) >= getModeConfig(modeId).minPlayers then
			pendingStarts[modeId] = true
			markModePending(modeId)
		end
		return
	end

	if shouldStartNow(modeId) then
		launchMatch(modeId)
		return
	end

	local config = getModeConfig(modeId)
	if modeId == "ffa" and queueCount(modeId) >= config.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	elseif modeId ~= "ffa" and queueCount(modeId) >= config.minPlayers then
		launchMatch(modeId)
	end
end

function MatchmakingService.onArenaFree()
	MatchStateService.setBusy(false)

	for modeId in pairs(MatchmakingConfig.QUEUE_MODES) do
		if pendingStarts[modeId] or (queueCount(modeId) >= getModeConfig(modeId).minPlayers and not fillTimers[modeId]) then
			if queueCount(modeId) >= getModeConfig(modeId).minPlayers then
				launchMatch(modeId)
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end

	if playerEntry[player] then
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = "waiting",
	}

	MatchmakingService.sendUpdate(player)
	MatchmakingService.evaluateMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	removeFromQueue(player)
	MatchmakingService.sendUpdate(player)
	MatchmakingService.evaluateMode(modeId)
end

function MatchmakingService.init()
	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
