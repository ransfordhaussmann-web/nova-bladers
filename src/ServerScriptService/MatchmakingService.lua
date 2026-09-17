local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local MODE_IDS = { "training", "pvp", "ffa" }

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingMatch = nil

local function initQueues()
	for _, modeId in MODE_IDS do
		queues[modeId] = {}
		fillTokens[modeId] = 0
	end
end

local function getQueueList(modeId)
	local list = {}
	for player in queues[modeId] or {} do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function buildUpdatePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	local roster = getQueueList(modeId)
	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status or "waiting",
		count = #roster,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

local function broadcastQueue(modeId, status)
	local payload = buildUpdatePayload(modeId, status)
	for player in queues[modeId] or {} do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function broadcastPlayerQueue(player, status)
	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, status))
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] += 1
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	queues[modeId][player] = nil
	playerQueue[player] = nil
	cancelFillTimer(modeId)
	broadcastQueue(modeId, "waiting")
end

local function clearRosterFromQueues(roster)
	for _, player in roster do
		local modeId = playerQueue[player]
		if modeId then
			queues[modeId][player] = nil
			playerQueue[player] = nil
		end
	end
end

local function canStart(modeId, roster)
	local mode = MatchModes.get(modeId)
	local count = #roster
	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" and count >= mode.minPlayers then
		return false
	end
	return count >= mode.minPlayers
end

local function launchMatch(modeId, roster)
	clearRosterFromQueues(roster)
	cancelFillTimer(modeId)
	MatchStateService.setBusy(true)

	for _, player in roster do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, { status = "starting", modeId = modeId })
		end
	end

	MatchReady:Fire({
		mode = modeId,
		players = roster,
	})
end

local function tryStartMatch(modeId)
	local roster = getQueueList(modeId)
	if #roster == 0 then
		return
	end

	if not canStart(modeId, roster) then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = { mode = modeId, players = roster }
		for _, player in roster do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, "pending"))
			end
		end
		return
	end

	launchMatch(modeId, roster)
end

local function scheduleFfaFill(modeId)
	local mode = MatchModes.get(modeId)
	if modeId ~= "ffa" then
		return
	end

	local roster = getQueueList(modeId)
	if #roster < mode.minPlayers or #roster >= mode.maxPlayers then
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= fillTokens[modeId] then
			return
		end
		local current = getQueueList(modeId)
		if #current >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		broadcastPlayerQueue(player, "waiting")
		return
	end

	removeFromQueue(player)
	queues[modeId][player] = true
	playerQueue[player] = modeId
	broadcastQueue(modeId, "waiting")

	local mode = MatchModes.get(modeId)
	local count = #getQueueList(modeId)

	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif modeId == "ffa" and count >= mode.minPlayers then
		scheduleFfaFill(modeId)
	else
		tryStartMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

local function processPending()
	if pendingMatch and not MatchStateService.isBusy() then
		local match = pendingMatch
		pendingMatch = nil
		launchMatch(match.mode, match.players)
		return
	end

	for _, modeId in MODE_IDS do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if pendingMatch then
			local filtered = {}
			for _, p in pendingMatch.players do
				if p ~= player and p.Parent then
					table.insert(filtered, p)
				end
			end
			if #filtered == 0 then
				pendingMatch = nil
			else
				pendingMatch.players = filtered
			end
		end
	end)

	MatchStateService.onArenaFreed(processPending)
end

return MatchmakingService
