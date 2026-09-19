local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local ffaFillToken = 0
local leaveHubForArena

for modeId, _ in pairs(MatchModes.getAll()) do
	queues[modeId] = {}
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	local needed = math.max(0, mode.minPlayers - count)
	local status = "waiting"

	if count >= mode.minPlayers then
		status = MatchStateService.isArenaBusy() ? "pending" : "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		needed = needed,
		status = status,
		inQueue = playerQueue[player] == modeId,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, player in Players:GetPlayers() do
		if HubService.getPhase(player) == "hub" or isPlayerQueued(player) then
			local personal = buildQueuePayload(modeId, player)
			Remotes.QueueUpdate:FireClient(player, personal)
		end
	end
end

local function broadcastAllQueues()
	for modeId, _ in pairs(MatchModes.getAll()) do
		broadcastQueueUpdate(modeId)
	end
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if modeId == "ffa" then
		cancelFfaFillTimer()
	end

	broadcastQueueUpdate(modeId)
end

local function getReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local ready = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player.Parent then
			table.insert(ready, player)
		end
	end
	return ready
end

local function popPlayersFromQueue(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		if leaveHubForArena then
			leaveHubForArena(player)
		end
	end

	MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})

	broadcastAllQueues()
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)

	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			local ready = getReadyPlayers(modeId)
			popPlayersFromQueue(modeId, ready)
			cancelFfaFillTimer()
			startMatch(modeId, ready)
		end
		return
	end

	local ready = getReadyPlayers(modeId)
	if #ready >= mode.minPlayers then
		popPlayersFromQueue(modeId, ready)
		startMatch(modeId, ready)
	end
end

local function scheduleFfaFill()
	cancelFfaFillTimer()
	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end

		local count = getQueueCount("ffa")
		local mode = MatchModes.ffa
		if count < mode.minPlayers then
			return
		end

		if MatchStateService.isArenaBusy() then
			broadcastQueueUpdate("ffa")
			return
		end

		local ready = getReadyPlayers("ffa")
		if #ready >= mode.minPlayers then
			popPlayersFromQueue("ffa", ready)
			startMatch("ffa", ready)
		end
	end)
end

local function onFfaQueueChanged()
	local count = getQueueCount("ffa")
	local mode = MatchModes.ffa

	if count < mode.minPlayers then
		cancelFfaFillTimer()
		return
	end

	if count >= mode.maxPlayers then
		tryStartMatch("ffa")
		return
	end

	if count == mode.minPlayers then
		scheduleFfaFill()
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	if isPlayerQueued(player) then
		if playerQueue[player] == modeId then
			return true, "already_queued"
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	Remotes.QueueJoin:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)

	if modeId == "ffa" then
		onFfaQueueChanged()
	else
		tryStartMatch(modeId)
	end

	return true, "joined"
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerQueued(player) then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueLeave:FireClient(player, { modeId = modeId })
	return true
end

function MatchmakingService.joinRecommendedQueue(player)
	return MatchmakingService.joinQueue(player, getRecommendedModeId())
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.init(options)
	leaveHubForArena = options.leaveHubForArena

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)
		task.defer(function()
			for modeId, _ in pairs(MatchModes.getAll()) do
				tryStartMatch(modeId)
				if modeId == "ffa" and getQueueCount("ffa") >= MatchModes.ffa.minPlayers then
					scheduleFfaFill()
				end
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if isPlayerQueued(player) then
			removeFromQueue(player)
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
