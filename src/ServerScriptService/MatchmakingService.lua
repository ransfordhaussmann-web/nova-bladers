local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerToMode = {}
local fillTokens = {}
local remotes = nil
local matchReadyBindable = nil
local onMatchFormed = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerToMode[player]
	if not modeId then
		return nil
	end

	playerToMode[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	return modeId
end

local function addToQueue(player, modeId)
	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerToMode[player] = modeId
end

local function buildQueuePayload(player)
	local modeId = playerToMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local status = "waiting"
	if #queue >= mode.minPlayers and MatchStateService.isArenaBusy() then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function broadcastQueueUpdate()
	if not remotes then
		return
	end

	for player in playerToMode do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function takeMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local matchPlayers = {}

	for index = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[index])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	fillTokens[modeId] = nil
	return matchPlayers
end

local function launchMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate()
		return false
	end

	local matchPlayers = takeMatchPlayers(modeId)
	if #matchPlayers == 0 then
		return false
	end

	for _, player in matchPlayers do
		if player.Parent and remotes then
			remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end

	if onMatchFormed then
		onMatchFormed(matchPlayers, modeId)
	end

	if matchReadyBindable then
		matchReadyBindable:Fire(matchPlayers, modeId)
	end

	broadcastQueueUpdate()
	return true
end

local function scheduleFillStart(modeId)
	local mode = MatchModes.get(modeId)
	if mode.fillTimeout <= 0 then
		launchMatch(modeId)
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		launchMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue >= mode.maxPlayers then
		launchMatch(modeId)
	elseif #queue >= mode.minPlayers then
		scheduleFillStart(modeId)
	end

	broadcastQueueUpdate()
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false
	end
	if playerToMode[player] == modeId then
		broadcastQueueUpdate()
		return true
	end

	addToQueue(player, modeId)
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerToMode[player] then
		return false
	end

	removeFromQueue(player)
	if remotes then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.isInQueue(player)
	return playerToMode[player] ~= nil
end

function MatchmakingService.onArenaFreed()
	for modeId, queue in queues do
		if #queue >= MatchModes.get(modeId).minPlayers then
			launchMatch(modeId)
		end
	end
	broadcastQueueUpdate()
end

function MatchmakingService.start(options)
	remotes = options.remotes
	matchReadyBindable = options.matchReadyBindable
	onMatchFormed = options.onMatchFormed

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)
end

return MatchmakingService
