--[[
	MatchmakingService — per-mode queues, fill timeouts, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
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
local ffaFillStartedAt = nil
local pendingMatch = nil
local started = false
local onSendToArena = nil

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function modeLabel(modeId)
	local mode = MatchModes.get(modeId)
	return mode and mode.label or modeId
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local count = getQueueSize(modeId)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersWaiting = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pendingMatch ~= nil and MatchStateService.isArenaBusy(),
	}

	if modeId == "ffa" and ffaFillStartedAt and count >= mode.minPlayers then
		local elapsed = os.clock() - ffaFillStartedAt
		payload.fillTimeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
		payload.fillRemaining = math.max(0, payload.fillTimeout - elapsed)
	end

	return payload
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })

	if modeId == "ffa" and getQueueSize("ffa") < MatchModes.get("ffa").minPlayers then
		ffaFillStartedAt = nil
	end

	broadcastQueue(modeId)
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function dispatchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = playerList }
		for _, player in playerList do
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = modeLabel(modeId),
				pending = true,
				playersWaiting = #playerList,
			})
		end
		return
	end

	pendingMatch = nil
	ffaFillStartedAt = nil

	for _, player in playerList do
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		if onSendToArena then
			onSendToArena(player)
		end
	end

	task.delay(MatchmakingConfig.MATCH_READY_DELAY, function()
		MatchReady:Fire({
			mode = modeId,
			players = playerList,
		})
	end)
end

local function tryStartTraining()
	local mode = MatchModes.get("training")
	if getQueueSize("training") < mode.minPlayers then
		return
	end
	dispatchMatch("training", takePlayers("training", mode.maxPlayers))
end

local function tryStartPvP()
	local mode = MatchModes.get("pvp")
	if getQueueSize("pvp") < mode.minPlayers then
		return
	end
	dispatchMatch("pvp", takePlayers("pvp", mode.maxPlayers))
end

local function tryStartFFA()
	local mode = MatchModes.get("ffa")
	local count = getQueueSize("ffa")
	if count < mode.minPlayers then
		ffaFillStartedAt = nil
		return
	end

	if not ffaFillStartedAt then
		ffaFillStartedAt = os.clock()
		broadcastQueue("ffa")
		return
	end

	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
	local elapsed = os.clock() - ffaFillStartedAt
	if count >= mode.maxPlayers or elapsed >= timeout then
		local takeCount = math.min(count, mode.maxPlayers)
		dispatchMatch("ffa", takePlayers("ffa", takeCount))
	end
end

local function processQueues()
	tryStartTraining()
	tryStartPvP()
	tryStartFFA()
end

local function processPending()
	if not pendingMatch or MatchStateService.isArenaBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	dispatchMatch(match.modeId, match.players)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		clearPlayerFromQueues(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueue(modeId)
	processQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	clearPlayerFromQueues(player)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setIdle()
	task.defer(function()
		processPending()
		processQueues()
	end)
end

function MatchmakingService.registerHandlers(handlers)
	onSendToArena = handlers.sendToArena
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if pendingMatch then
			local filtered = {}
			for _, queuedPlayer in pendingMatch.players do
				if queuedPlayer ~= player and queuedPlayer.Parent then
					table.insert(filtered, queuedPlayer)
				end
			end
			if #filtered == 0 then
				pendingMatch = nil
			else
				pendingMatch.players = filtered
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			processQueues()
			if ffaFillStartedAt then
				broadcastQueue("ffa")
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
