local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReadyBindable

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local started = false
local onMatchStart
local onQueueLeave

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

	if fillTimers[modeId] and #queue < MatchModes.get(modeId).minPlayers then
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local needed = mode.minPlayers

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		needed = needed,
		maxPlayers = mode.maxPlayers,
		status = status,
		inQueue = playerQueue[player] == modeId,
		position = playerQueue[player] == modeId and table.find(queue, player) or nil,
		message = status == "pending"
			and MatchmakingConfig.PENDING_MESSAGE
			or (count >= needed and MatchmakingConfig.STARTING_MESSAGE or MatchmakingConfig.WAITING_MESSAGE),
	}
end

local function broadcastQueueUpdate(modeId, status)
	local payload = {}
	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId then
			payload[player] = buildQueuePayload(player, modeId, status or "waiting")
		end
	end

	for player, data in payload do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, data)
		end
	end
end

local function broadcastAllQueues()
	local status = if MatchStateService.isBusy() then "pending" else "waiting"
	for modeId in queues do
		broadcastQueueUpdate(modeId, status)
	end
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	fillTimers[modeId] = nil
	return taken
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return false
	end

	if mode.maxPlayers and count >= mode.maxPlayers then
		return true
	end

	if mode.fillTimeout and fillTimers[modeId] then
		local elapsed = os.clock() - fillTimers[modeId]
		if elapsed >= mode.fillTimeout then
			return true
		end
	end

	if not mode.fillTimeout and count >= mode.minPlayers then
		return true
	end

	return false
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end
	if fillTimers[modeId] then
		return
	end
	if #getQueue(modeId) < mode.minPlayers then
		return
	end
	fillTimers[modeId] = os.clock()
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	for _, player in playerList do
		removeFromQueue(player)
	end

	broadcastAllQueues()

	if onMatchStart then
		onMatchStart(playerList, modeId)
	end

	task.delay(MatchmakingConfig.START_DELAY, function()
		if MatchReadyBindable then
			MatchReadyBindable:Fire({
				modeId = modeId,
				players = playerList,
			})
		end
	end)
end

local function tryStartMatches()
	if MatchStateService.isBusy() then
		broadcastAllQueues()
		return
	end

	for _, mode in MatchModes.all() do
		local modeId = mode.id
		startFillTimer(modeId)

		if canStartMode(modeId) then
			local count = math.min(#getQueue(modeId), mode.maxPlayers)
			local players = takePlayers(modeId, count)
			if #players > 0 then
				launchMatch(modeId, players)
				return
			end
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	local status = if MatchStateService.isBusy() then "pending" else "waiting"
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
	broadcastQueueUpdate(modeId, status)

	tryStartMatches()
	return true
end

function MatchmakingService.joinQuickMatch(player)
	local mode = MatchModes.resolveQuickMatch(#Players:GetPlayers())
	return MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	local status = if MatchStateService.isBusy() then "pending" else "waiting"
	broadcastQueueUpdate(modeId, status)

	if onQueueLeave then
		onQueueLeave(player)
	end
	return true
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	return playerQueue[player]
end

function MatchmakingService.setMatchStartHandler(handler)
	onMatchStart = handler
end

function MatchmakingService.setQueueLeaveHandler(handler)
	onQueueLeave = handler
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReadyBindable = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinQuickMatch(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onBusyChanged(function(busy)
		if not busy then
			tryStartMatches()
		else
			broadcastAllQueues()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.TICK_INTERVAL)
			tryStartMatches()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
