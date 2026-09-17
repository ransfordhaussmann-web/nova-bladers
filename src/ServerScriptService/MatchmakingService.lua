local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillToken = 0
local pendingMatch = nil
local started = false

local function getQueueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	return #queue
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	local pending = pendingMatch ~= nil and MatchStateService.isArenaBusy()
	if not pending and mode then
		pending = MatchStateService.isArenaBusy() and size >= mode.minPlayers
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueSize = size,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pending,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate()
	for player, _ in playerMode do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if modeId == "ffa" and #queues.ffa < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerMode[nextPlayer] = nil
			table.insert(taken, nextPlayer)
		end
	end
	return taken
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
	end

	pendingMatch = nil
	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		if HubService.getPhase(player) ~= "arena" then
			HubService.enterArena(player)
		end
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
	broadcastQueueUpdate()
end

local function tryStartReadyMatch()
	if MatchStateService.isArenaBusy() then
		return
	end

	if pendingMatch then
		local mode = MatchModes.get(pendingMatch.mode)
		if mode and getQueueSize(mode.id) >= mode.minPlayers then
			local players = takePlayers(mode.id, mode.maxPlayers)
			pendingMatch = nil
			if #players >= mode.minPlayers then
				launchMatch(mode.id, players)
			end
		end
		return
	end

	for _, mode in MatchModes.all() do
		local queue = queues[mode.id]
		if #queue >= mode.maxPlayers then
			local players = takePlayers(mode.id, mode.maxPlayers)
			if #players >= mode.minPlayers then
				launchMatch(mode.id, players)
				return
			end
			for _, player in players do
				table.insert(queue, 1, player)
				playerMode[player] = mode.id
			end
		end
	end

	for _, mode in MatchModes.all() do
		if mode.id == "ffa" then
			continue
		end
		local queue = queues[mode.id]
		if #queue >= mode.minPlayers then
			local players = takePlayers(mode.id, mode.minPlayers)
			if #players >= mode.minPlayers then
				launchMatch(mode.id, players)
				return
			end
		end
	end
end

local function scheduleFfaFill()
	local token = ffaFillToken + 1
	ffaFillToken = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		if #queues.ffa < MatchModes.ffa.minPlayers then
			return
		end
		if MatchStateService.isArenaBusy() then
			pendingMatch = { mode = "ffa" }
			broadcastQueueUpdate()
			return
		end

		local players = takePlayers("ffa", MatchModes.ffa.maxPlayers)
		if #players >= MatchModes.ffa.minPlayers then
			launchMatch("ffa", players)
		end
	end)
end

local function queuePlayer(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end
	if HubService.getPhase(player) == "arena" then
		return false, "already_in_arena"
	end
	if playerMode[player] == modeId then
		return true
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	if modeId == "ffa" and #queues.ffa >= MatchModes.ffa.minPlayers then
		scheduleFfaFill()
	end

	broadcastQueueUpdate()
	tryStartReadyMatch()
	return true
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
		queuePlayer(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		removeFromQueue(player)
		broadcastQueueUpdate()
		tryStartReadyMatch()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		broadcastQueueUpdate()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastQueueUpdate()
		end
	end)

	print("[MatchmakingService] Queue ready")
end

function MatchmakingService.joinQueue(player, modeId)
	return queuePlayer(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
	broadcastQueueUpdate()
	tryStartReadyMatch()
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	tryStartReadyMatch()
end

function MatchmakingService.getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= MatchModes.ffa.minPlayers then
		return "ffa"
	elseif count >= MatchModes.pvp.minPlayers then
		return "pvp"
	end
	return "training"
end

return MatchmakingService
