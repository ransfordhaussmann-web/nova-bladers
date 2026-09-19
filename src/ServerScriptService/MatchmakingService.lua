--[[
	MatchmakingService — mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local activeFill = {}
local remotes
local bindables
local hubCallbacks
local initialized = false

local function getModeIdForPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function removeFromModeQueue(player, modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return "idle"
	end

	local count = #queues[modeId]
	if count == 0 then
		return "idle"
	end
	if MatchStateService.isBusy() then
		return "pending"
	end
	if count >= mode.maxPlayers then
		return "ready"
	end
	if count >= mode.minPlayers then
		if mode.fillTimeout then
			return "filling"
		end
		return "ready"
	end
	return "waiting"
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local names = {}
	for _, queued in queue do
		if queued.Parent then
			table.insert(names, queued.Name)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = names,
		status = getQueueStatus(modeId),
		inQueue = player ~= nil and playerQueue[player] == modeId,
		arenaBusy = MatchStateService.isBusy(),
	}
end

local function sendQueueUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			arenaBusy = MatchStateService.isBusy(),
		})
		return
	end
	remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
end

local function broadcastModeQueue(modeId)
	for player, queuedMode in playerQueue do
		if queuedMode == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function broadcastAllQueues()
	for player in playerQueue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	activeFill[modeId] = nil
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	for _, player in playerList do
		if hubCallbacks.leaveHubForArena then
			hubCallbacks.leaveHubForArena(player)
		end
	end

	bindables.MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})

	broadcastAllQueues()
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or MatchStateService.isBusy() then
		broadcastModeQueue(modeId)
		return false
	end

	local count = #queues[modeId]
	if count < mode.minPlayers then
		broadcastModeQueue(modeId)
		return false
	end

	if count >= mode.maxPlayers then
		cancelFillTimer(modeId)
		local players = popPlayers(modeId, mode.maxPlayers)
		launchMatch(modeId, players)
		return true
	end

	if mode.fillTimeout and count >= mode.minPlayers then
		if not activeFill[modeId] then
			local token = {}
			activeFill[modeId] = token
			broadcastModeQueue(modeId)

			task.delay(mode.fillTimeout, function()
				if activeFill[modeId] ~= token or MatchStateService.isBusy() then
					return
				end
				activeFill[modeId] = nil

				local readyCount = #queues[modeId]
				if readyCount >= mode.minPlayers then
					local players = popPlayers(modeId, math.min(readyCount, mode.maxPlayers))
					launchMatch(modeId, players)
				else
					broadcastModeQueue(modeId)
				end
			end)
		end
		return false
	end

	if count >= mode.minPlayers then
		cancelFillTimer(modeId)
		local players = popPlayers(modeId, mode.maxPlayers)
		launchMatch(modeId, players)
		return true
	end

	broadcastModeQueue(modeId)
	return false
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	removeFromModeQueue(player, modeId)

	local mode = MatchModes.get(modeId)
	if mode and #queues[modeId] < mode.minPlayers then
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastModeQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if hubCallbacks.getPhase and hubCallbacks.getPhase(player) ~= "hub" then
		return
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastModeQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.joinRecommendedQueue(player)
	local count = #Players:GetPlayers()
	MatchmakingService.joinQueue(player, getModeIdForPlayerCount(count))
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(function()
		for modeId in queues do
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.init(remoteFolder, bindableFolder, callbacks)
	if initialized then
		return
	end
	initialized = true

	remotes = remoteFolder
	bindables = bindableFolder
	hubCallbacks = callbacks or {}

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinRecommendedQueue(player)
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)
end

return MatchmakingService
