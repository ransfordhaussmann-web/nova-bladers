local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local playerStatus = {}
local fillTokens = {}
local fillScheduled = {}
local pendingRosters = {}
local onMatchStart = nil
local started = false

local function getQueueList(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function removeFromQueueList(modeId, player)
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end

local function setPlayerStatus(player, status, extra)
	playerStatus[player] = {
		status = status,
		modeId = extra and extra.modeId,
		position = extra and extra.position,
		needed = extra and extra.needed,
	}
end

local function clearPlayerStatus(player)
	playerStatus[player] = nil
end

local function buildQueuePayload(modeId, forPlayer)
	local mode = MatchModes.get(modeId)
	local list = getQueueList(modeId)
	local names = {}
	for _, p in list do
		table.insert(names, p.DisplayName)
	end

	local position = 0
	for i, p in list do
		if p == forPlayer then
			position = i
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = playerStatus[forPlayer] and playerStatus[forPlayer].status or "queued",
	}
end

local function broadcastQueueUpdate(modeId)
	local list = getQueueList(modeId)
	for _, player in list do
		QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	end
end

local function broadcastPending(roster)
	for _, player in roster do
		if player.Parent then
			local modeId = playerStatus[player] and playerStatus[player].modeId
			QueueUpdate:FireClient(player, {
				modeId = modeId,
				status = "pending",
				count = #roster,
				players = (function()
					local names = {}
					for _, p in roster do
						table.insert(names, p.DisplayName)
					end
					return names
				end)(),
			})
		end
	end
end

local function pullPlayers(modeId, count)
	local pulled = {}
	local queue = getQueueList(modeId)
	for i = 1, math.min(count, #queue) do
		local player = queue[i]
		table.insert(pulled, player)
	end

	for _, player in pulled do
		removeFromQueueList(modeId, player)
		playerQueue[player] = nil
	end

	return pulled
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillScheduled[modeId] = false
end

local function launchMatch(modeId, roster)
	for _, player in roster do
		setPlayerStatus(player, "starting", { modeId = modeId })
		if onMatchStart then
			onMatchStart(player, modeId)
		end
	end

	if MatchStateService.isArenaBusy() then
		table.insert(pendingRosters, { modeId = modeId, players = roster })
		broadcastPending(roster)
		return
	end

	for _, player in roster do
		clearPlayerStatus(player)
	end
	MatchReady:Fire(roster, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = #getQueueList(modeId)
	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		cancelFillTimer(modeId)
		local roster = pullPlayers(modeId, mode.maxPlayers)
		broadcastQueueUpdate(modeId)
		launchMatch(modeId, roster)
		return
	end

	if mode.fillTimeout and count >= mode.minPlayers then
		if not fillScheduled[modeId] then
			fillScheduled[modeId] = true
			local token = (fillTokens[modeId] or 0) + 1
			fillTokens[modeId] = token
			task.delay(mode.fillTimeout, function()
				if fillTokens[modeId] ~= token then
					return
				end
				fillScheduled[modeId] = false
				local current = #getQueueList(modeId)
				if current < mode.minPlayers then
					return
				end
				local roster = pullPlayers(modeId, math.min(current, mode.maxPlayers))
				broadcastQueueUpdate(modeId)
				launchMatch(modeId, roster)
			end)
		end
		return
	end

	if not mode.fillTimeout and count >= mode.minPlayers then
		cancelFillTimer(modeId)
		local roster = pullPlayers(modeId, mode.minPlayers)
		broadcastQueueUpdate(modeId)
		launchMatch(modeId, roster)
	end
end

local function processPending()
	if MatchStateService.isArenaBusy() then
		return
	end
	if #pendingRosters == 0 then
		return
	end

	local nextMatch = table.remove(pendingRosters, 1)
	local roster = {}
	for _, player in nextMatch.players do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(roster, player)
		end
	end

	if #roster == 0 then
		task.defer(processPending)
		return
	end

	local mode = MatchModes.get(nextMatch.modeId)
	if not mode or #roster < mode.minPlayers then
		for _, player in roster do
			MatchmakingService.joinQueue(player, nextMatch.modeId)
		end
		task.defer(processPending)
		return
	end

	for _, player in roster do
		clearPlayerStatus(player)
		if onMatchStart then
			onMatchStart(player, nextMatch.modeId)
		end
	end
	MatchReady:Fire(roster, nextMatch.modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	setPlayerStatus(player, "queued", { modeId = modeId })
	QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueueList(modeId, player)
	playerQueue[player] = nil
	clearPlayerStatus(player)

	if fillTokens[modeId] and #getQueueList(modeId) < MatchModes.get(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	QueueUpdate:FireClient(player, { status = "idle" })
	broadcastQueueUpdate(modeId)

	for i = #pendingRosters, 1, -1 do
		local roster = pendingRosters[i]
		for j, p in roster.players do
			if p == player then
				table.remove(roster.players, j)
				break
			end
		end
		if #roster.players == 0 then
			table.remove(pendingRosters, i)
		end
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.resolveQuickMatchMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start(handlers)
	if started then
		return
	end
	started = true
	onMatchStart = handlers and handlers.onMatchStart

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" or modeId == nil then
			modeId = MatchmakingService.resolveQuickMatchMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		task.defer(processPending)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
