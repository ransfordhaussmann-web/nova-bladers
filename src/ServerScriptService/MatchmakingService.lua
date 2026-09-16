--[[
	MatchmakingService — per-mode queues with FFA fill timeout and arena-busy pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local bindables
local hubService

local queues = {}
local playerMode = {}
local ffaTimers = {}

local function newQueue()
	return {
		players = {},
		fillDeadline = nil,
	}
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = newQueue()
	end
	return queues[modeId]
end

local function queueCount(modeId)
	return #getQueue(modeId).players
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, i)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" then
		local count = #queue.players
		if count < MatchModes.ffa.minPlayers then
			queue.fillDeadline = nil
			if ffaTimers[modeId] then
				task.cancel(ffaTimers[modeId])
				ffaTimers[modeId] = nil
			end
		end
	end
end

local function getPlayerStatus(player)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	return "waiting"
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local count = queueCount(modeId)
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = getPlayerStatus(player),
	}
end

local function broadcastQueueUpdate()
	for player, _ in playerMode do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function clearPlayerQueueState(player)
	if playerMode[player] then
		removeFromQueue(player)
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

local function isQueueReady(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers then
		return false
	end

	if count >= mode.maxPlayers then
		return true
	end

	if modeId == "ffa" then
		local queue = getQueue(modeId)
		if queue.fillDeadline and os.clock() >= queue.fillDeadline then
			return true
		end
		return false
	end

	return count >= mode.minPlayers
end

local function popReadyPlayers(modeId)
	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)
	local count = math.min(#queue.players, mode.maxPlayers)
	local matched = {}

	for i = 1, count do
		table.insert(matched, queue.players[i])
	end

	for i = count, 1, -1 do
		local player = table.remove(queue.players, i)
		playerMode[player] = nil
	end

	queue.fillDeadline = nil
	if ffaTimers[modeId] then
		task.cancel(ffaTimers[modeId])
		ffaTimers[modeId] = nil
	end

	return matched
end

local function startMatch(modeId, matchedPlayers)
	if #matchedPlayers == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in matchedPlayers do
		if player.Parent and hubService.leaveHubForArena then
			hubService.leaveHubForArena(player)
		end
		remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end

	bindables.MatchReady:Fire({
		mode = modeId,
		players = matchedPlayers,
	})
end

local function tryStartMatches()
	if MatchStateService.isArenaBusy() then
		return
	end

	for _, modeId in MatchModes.getOrderedIds() do
		if isQueueReady(modeId) then
			local matched = popReadyPlayers(modeId)
			if #matched > 0 then
				startMatch(modeId, matched)
				broadcastQueueUpdate()
				return
			end
		end
	end
end

local function scheduleFfaFillCheck()
	local modeId = "ffa"
	if ffaTimers[modeId] then
		return
	end

	local queue = getQueue(modeId)
	if not queue.fillDeadline then
		return
	end

	local delay = math.max(0, queue.fillDeadline - os.clock())
	ffaTimers[modeId] = task.delay(delay, function()
		ffaTimers[modeId] = nil
		tryStartMatches()
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return false
	end

	if hubService.getPhase(player) ~= "hub" then
		return false
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	table.insert(queue.players, player)
	playerMode[player] = modeId

	if modeId == "ffa" and #queue.players == MatchModes.ffa.minPlayers and not queue.fillDeadline then
		queue.fillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		scheduleFfaFillCheck()
	end

	broadcastQueueUpdate()
	tryStartMatches()
	return true
end

function MatchmakingService.leaveQueue(player)
	clearPlayerQueueState(player)
	broadcastQueueUpdate()
end

function MatchmakingService.onArenaFreed()
	MatchStateService.setArenaBusy(false)
	broadcastQueueUpdate()
	tryStartMatches()
end

function MatchmakingService.getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start(remoteFolder, bindableFolder, hubApi)
	remotes = remoteFolder
	bindables = bindableFolder
	hubService = hubApi

	for _, modeId in MatchModes.getOrderedIds() do
		queues[modeId] = newQueue()
	end

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
			modeId = MatchmakingService.getActiveModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		clearPlayerQueueState(player)
		broadcastQueueUpdate()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
