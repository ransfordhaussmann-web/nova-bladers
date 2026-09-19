local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerMode = {}
local ffaFillToken = 0
local hubCallbacks = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
	playerMode[player] = nil
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.Name)
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = names,
		pending = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(players)
	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function broadcastModeQueue(modeId)
	local queue = getQueue(modeId)
	broadcastQueueUpdate(queue)
end

local function collectReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local ready = {}

	for i = 1, math.min(#queue, mode.maxPlayers) do
		local player = queue[i]
		if player.Parent and hubCallbacks.getPhase(player) == "hub" then
			table.insert(ready, player)
		end
	end

	if #ready < mode.minPlayers then
		return nil
	end

	return ready
end

local function dequeuePlayers(players)
	for _, player in players do
		removeFromQueue(player)
	end
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		if hubCallbacks.leaveHubForArena then
			hubCallbacks.leaveHubForArena(player)
		end
	end

	Bindables.MatchReady:Fire({
		players = playerList,
		mode = modeId,
	})

	broadcastQueueUpdate(playerList)
end

local function tryStartMatch(modeId, force)
	if MatchStateService.isArenaBusy() then
		broadcastModeQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" and not force and #queue < mode.maxPlayers then
		return
	end

	local ready = collectReadyPlayers(modeId)
	if not ready then
		return
	end

	dequeuePlayers(ready)
	launchMatch(modeId, ready)
end

local function tryStartAllQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

local function scheduleFfaFill()
	ffaFillToken += 1
	local token = ffaFillToken
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		tryStartMatch("ffa", true)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchModes.getRecommended(#Players:GetPlayers())
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if hubCallbacks.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId

	if modeId == "ffa" and #getQueue("ffa") == mode.minPlayers then
		scheduleFfaFill()
	elseif #getQueue(modeId) >= mode.maxPlayers then
		ffaFillToken += 1
	end

	broadcastModeQueue(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)

	if modeId == "ffa" then
		ffaFillToken += 1
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastModeQueue(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(tryStartAllQueues)
end

function MatchmakingService.init(callbacks)
	Remotes, Bindables = RemotesSetup.ensure()
	hubCallbacks = callbacks or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerMode[player] then
			local modeId = playerMode[player]
			removeFromQueue(player)
			if modeId == "ffa" then
				ffaFillToken += 1
			end
			broadcastModeQueue(modeId)
			tryStartMatch(modeId)
		end
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
