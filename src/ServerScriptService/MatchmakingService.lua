local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

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
local onMatchStart = nil

local function getQuickMatchModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local size = getQueueSize(entry.modeId)
	local pending = MatchStateService.isArenaBusy()

	local status
	if pending then
		status = "Warte auf Arena..."
	elseif size >= mode.minPlayers then
		status = "Startet bald..."
	else
		status = "Suche Gegner..."
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		players = size,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		status = status,
	}
end

local function broadcastQueueUpdate()
	for player, _ in playerQueue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
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
	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(picked, player)
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setBusy()
	broadcastQueueUpdate()

	if onMatchStart then
		onMatchStart(playerList, modeId)
	end
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	if size >= mode.maxPlayers then
		startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.fillTimeout > 0 then
		if not fillTimers[modeId] then
			local token = { cancelled = false }
			fillTimers[modeId] = token
			task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if token.cancelled or MatchStateService.isArenaBusy() then
					return
				end
				local currentSize = getQueueSize(modeId)
				if currentSize >= mode.minPlayers then
					local count = math.min(currentSize, mode.maxPlayers)
					startMatch(modeId, popPlayers(modeId, count))
				end
			end)
		end
		return
	end

	startMatch(modeId, popPlayers(modeId, size))
end

local function tryStartAllQueues()
	for modeId, _ in queues do
		tryStartMode(modeId)
		if MatchStateService.isArenaBusy() then
			break
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getQuickMatchModeId()
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "Unbekannter Modus"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }
	broadcastQueueUpdate()
	tryStartAllQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate()
end

function MatchmakingService.getQuickMatchModeId()
	return getQuickMatchModeId()
end

function MatchmakingService.onArenaIdle()
	MatchStateService.setIdle()
	broadcastQueueUpdate()
	tryStartAllQueues()
end

function MatchmakingService.init(handlers)
	onMatchStart = handlers and handlers.onMatchStart

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
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
