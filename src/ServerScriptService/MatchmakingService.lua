local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local started = false

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function getQueueStatus(modeId)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)
	if modeId == "ffa" and fillTimers[modeId] and #queue >= mode.minPlayers then
		return "filling"
	end
	return "searching"
end

local function buildQueuePayload(modeId, player, position)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	return {
		modeId = modeId,
		label = mode.label,
		desc = mode.desc,
		position = position,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getQueueStatus(modeId),
		fillTimeout = mode.fillTimeout,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for i, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player, i))
		end
	end
end

local function clearFillTimer(modeId)
	if fillTimers[modeId] then
		fillTimers[modeId] = nil
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local players = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(players, player)
			playerQueue[player] = nil
			Remotes.QueueUpdate:FireClient(player, { status = "matched" })
		end
	end
	return players
end

local function launchMatch(modeId, count)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	clearFillTimer(modeId)
	local players = popPlayers(modeId, count or #queue)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	for _, player in players do
		HubService.leaveHubForArena(player)
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire({
		players = players,
		modeId = modeId,
	})

	broadcastQueue(modeId)
	return true
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if modeId == "training" and #queue >= 1 then
		launchMatch(modeId, 1)
	elseif modeId == "pvp" and #queue >= mode.maxPlayers then
		launchMatch(modeId, mode.maxPlayers)
	elseif modeId == "ffa" and #queue >= mode.maxPlayers then
		launchMatch(modeId, mode.maxPlayers)
	elseif modeId == "ffa" and #queue >= mode.minPlayers and not fillTimers[modeId] then
		fillTimers[modeId] = true
		broadcastQueue(modeId)
		task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
			fillTimers[modeId] = nil
			if #getQueue(modeId) >= mode.minPlayers then
				launchMatch(modeId, math.min(#getQueue(modeId), mode.maxPlayers))
			end
		end)
	else
		broadcastQueue(modeId)
	end
end

local function tryStartAllQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		broadcastQueue(modeId)
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	if modeId == "ffa" and #getQueue(modeId) < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

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

	MatchStateService.onArenaFree(function()
		tryStartAllQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			for _, mode in MatchModes.all() do
				if #getQueue(mode.id) > 0 then
					broadcastQueue(mode.id)
				end
			end
		end
	end)
end

return MatchmakingService
