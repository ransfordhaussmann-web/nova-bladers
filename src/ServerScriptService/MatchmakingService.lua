local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local pendingMatch = nil
local ffaFillToken = 0
local remotes
local matchReadyBindable
local hubCallbacks = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function compactQueue(modeId)
	local queue = getQueue(modeId)
	local compact = {}
	for _, player in queue do
		if player.Parent and playerEntry[player] and playerEntry[player].modeId == modeId then
			table.insert(compact, player)
		end
	end
	queues[modeId] = compact
end

local function buildUpdate(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	compactQueue(modeId)

	local playersInQueue = #queue
	local playersNeeded = mode and mode.minPlayers or 1
	local message

	if status == "pending" then
		message = "Arena belegt — warte auf freies Match..."
	elseif status == "starting" then
		message = "Match startet..."
	elseif modeId == "ffa" and playersInQueue >= mode.minPlayers and playersInQueue < mode.maxPlayers then
		message = string.format("FFA: %d/%d — Fill-Timer läuft", playersInQueue, mode.maxPlayers)
	else
		message = string.format("%s: %d/%d Spieler", mode and mode.label or modeId, playersInQueue, playersNeeded)
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		playersInQueue = playersInQueue,
		playersNeeded = playersNeeded,
		maxPlayers = mode and mode.maxPlayers or playersNeeded,
		status = status or "waiting",
		message = message,
	}
end

local function sendUpdate(player, payload)
	if player.Parent and remotes and remotes.QueueUpdate then
		remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId, status)
	compactQueue(modeId)
	for _, player in getQueue(modeId) do
		sendUpdate(player, buildUpdate(player, modeId, status))
	end
end

local function clearPlayerQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local queue = getQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	sendUpdate(player, { inQueue = false })
	broadcastQueue(modeId, "waiting")
end

local function removePlayersFromQueues(playerList)
	for _, player in playerList do
		clearPlayerQueue(player)
	end
end

local function launchMatch(modeId, playerList)
	local valid = {}
	for _, player in playerList do
		if player.Parent then
			table.insert(valid, player)
		end
	end

	if #valid == 0 then
		return
	end

	removePlayersFromQueues(valid)

	if hubCallbacks.onMatchReady then
		hubCallbacks.onMatchReady(valid, modeId)
	end

	matchReadyBindable:Fire(valid, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	compactQueue(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local roster = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(roster, queue[i])
	end

	if GameMatchState.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = roster,
		}
		for _, player in roster do
			sendUpdate(player, buildUpdate(player, modeId, "pending"))
		end
		return
	end

	launchMatch(modeId, roster)
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function scheduleFfaFill(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	cancelFfaFillTimer()
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		compactQueue(modeId)
		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.resolveActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.getQueueSize(modeId)
	compactQueue(modeId)
	return #getQueue(modeId)
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end
	local modeId = playerEntry[player].modeId
	clearPlayerQueue(player)
	if modeId == "ffa" then
		cancelFfaFillTimer()
		scheduleFfaFill("ffa")
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		modeId = MatchmakingService.resolveActiveModeId()
	end

	if playerEntry[player] then
		MatchmakingService.leaveQueue(player)
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerEntry[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	sendUpdate(player, buildUpdate(player, modeId, "waiting"))
	broadcastQueue(modeId, "waiting")

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			cancelFfaFillTimer()
			tryStartMatch(modeId)
		elseif #queue >= mode.minPlayers then
			scheduleFfaFill(modeId)
		end
	else
		tryStartMatch(modeId)
	end
end

function MatchmakingService.onArenaFree()
	if not pendingMatch then
		return
	end

	local match = pendingMatch
	pendingMatch = nil

	local mode = MatchModes.get(match.modeId)
	if not mode then
		return
	end

	local valid = {}
	for _, player in match.players do
		if player.Parent and playerEntry[player] and playerEntry[player].modeId == match.modeId then
			table.insert(valid, player)
		end
	end

	if #valid < mode.minPlayers then
		for _, player in valid do
			sendUpdate(player, buildUpdate(player, match.modeId, "waiting"))
		end
		broadcastQueue(match.modeId, "waiting")
		return
	end

	launchMatch(match.modeId, valid)
end

function MatchmakingService.registerHubCallbacks(callbacks)
	hubCallbacks = callbacks or {}
end

function MatchmakingService.start()
	remotes, _ = RemotesSetup.ensure()
	local _, bindables = RemotesSetup.ensure()
	matchReadyBindable = bindables.MatchReady

	if bindables.ArenaFree then
		bindables.ArenaFree.Event:Connect(function()
			MatchmakingService.onArenaFree()
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
