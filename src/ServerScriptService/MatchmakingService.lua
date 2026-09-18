local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local pendingRoster = nil
local leaveHubForArena
local getPlayerPhase

local function getQueueList(modeId)
	return queues[modeId]
end

local function findPlayerIndex(list, player)
	for i, p in list do
		if p == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local names = {}
	for _, player in list do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #names,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 6,
		fillTimeout = mode and mode.fillTimeout,
		playerNames = names,
		status = status or "waiting",
	}
end

local function broadcastQueue(modeId)
	local list = getQueueList(modeId)
	local payload = buildQueuePayload(modeId, pendingRoster and "pending" or "waiting")
	for _, player in list do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		if #getQueueList(modeId) > 0 then
			broadcastQueue(modeId)
		end
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local list = getQueueList(modeId)
	local index = findPlayerIndex(list, player)
	if index then
		table.remove(list, index)
	end
	playerQueue[player] = nil
	clearFillTimer(modeId)
	broadcastQueue(modeId)
end

local function rosterFromQueue(modeId)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local roster = {}
	for _, player in list do
		if player.Parent and #roster < mode.maxPlayers then
			table.insert(roster, player)
		end
	end
	return roster
end

local function dequeueRoster(roster)
	for _, player in roster do
		removeFromQueue(player)
	end
end

local function launchMatch(roster)
	pendingRoster = nil
	for _, player in roster do
		if player.Parent and leaveHubForArena then
			leaveHubForArena(player)
		end
	end
	MatchReady:Fire(roster)
end

local function notifyPendingPlayers(modeId, roster)
	local mode = MatchModes.get(modeId)
	for _, player in roster do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				modeLabel = mode and mode.label or modeId,
				count = #roster,
				minPlayers = mode and mode.minPlayers or 1,
				maxPlayers = mode and mode.maxPlayers or 6,
				status = "pending",
			})
		end
	end
end

local function tryLaunchRoster(modeId, roster)
	if #roster == 0 then
		return
	end

	dequeueRoster(roster)

	if MatchStateService.isArenaBusy() then
		pendingRoster = { modeId = modeId, players = roster }
		notifyPendingPlayers(modeId, roster)
		return
	end

	launchMatch(roster)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil

		local roster = rosterFromQueue(modeId)
		if #roster >= mode.minPlayers then
			tryLaunchRoster(modeId, roster)
		end
	end)
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local roster = rosterFromQueue(modeId)
	if #roster < mode.minPlayers then
		return
	end

	if #roster >= mode.maxPlayers then
		tryLaunchRoster(modeId, roster)
		return
	end

	if mode.fillTimeout then
		if not fillTimers[modeId] then
			scheduleFillTimeout(modeId)
			broadcastQueue(modeId)
		end
		return
	end

	tryLaunchRoster(modeId, roster)
end

local function processPendingMatch()
	if not pendingRoster or MatchStateService.isArenaBusy() then
		return
	end

	local roster = pendingRoster.players
	pendingRoster = nil

	local valid = {}
	for _, player in roster do
		if player.Parent then
			table.insert(valid, player)
		end
	end

	if #valid > 0 then
		launchMatch(valid)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if getPlayerPhase and getPlayerPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	local list = getQueueList(modeId)
	if #list >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(list, player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	evaluateQueue(modeId)
	return true
end

local function removeFromPendingRoster(player)
	if not pendingRoster then
		return
	end

	for i, p in pendingRoster.players do
		if p == player then
			table.remove(pendingRoster.players, i)
			break
		end
	end

	local mode = MatchModes.get(pendingRoster.modeId)
	if not mode or #pendingRoster.players < mode.minPlayers then
		for _, p in pendingRoster.players do
			if p.Parent and playerQueue[p] == nil then
				table.insert(getQueueList(pendingRoster.modeId), p)
				playerQueue[p] = pendingRoster.modeId
			end
		end
		pendingRoster = nil
	end
end

function MatchmakingService.leaveQueue(player)
	removeFromPendingRoster(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(options)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	leaveHubForArena = options.leaveHubForArena
	getPlayerPhase = options.getPlayerPhase

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		local ok, reason = MatchmakingService.joinQueue(player, modeId)
		if not ok and reason then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				status = "error",
				reason = reason,
			})
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		processPendingMatch()
		for modeId in queues do
			evaluateQueue(modeId)
		end
	end)
end

return MatchmakingService
