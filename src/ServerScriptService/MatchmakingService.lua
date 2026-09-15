local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local pendingMatches = {}
local ffaFillToken = 0
local ffaFillEndsAt = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
end

local function buildQueuePayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local queue = getQueue(entry.modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local fillRemaining = nil
	if entry.modeId == "ffa" and ffaFillEndsAt then
		fillRemaining = math.max(0, math.ceil(ffaFillEndsAt - os.clock()))
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		status = entry.status,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillSeconds = fillRemaining,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueUpdates()
	for player in playerEntry do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return nil
	end

	local count = math.min(#queue, mode.maxPlayers)
	local players = {}
	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(players, player)
			playerEntry[player] = nil
		end
	end

	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			playerEntry[player] = { modeId = modeId, status = "waiting" }
		end
		return nil
	end

	return players
end

local function removePlayerFromPending(player)
	for i = #pendingMatches, 1, -1 do
		local match = pendingMatches[i]
		local filtered = {}
		for _, queuedPlayer in match.players do
			if queuedPlayer ~= player then
				table.insert(filtered, queuedPlayer)
			end
		end

		if #filtered == 0 then
			table.remove(pendingMatches, i)
		else
			local mode = MatchModes.get(match.modeId)
			if #filtered < mode.minPlayers then
				table.remove(pendingMatches, i)
				for _, queuedPlayer in filtered do
					playerEntry[queuedPlayer] = nil
					table.insert(getQueue(match.modeId), queuedPlayer)
					playerEntry[queuedPlayer] = { modeId = match.modeId, status = "waiting" }
				end
			else
				match.players = filtered
				for _, queuedPlayer in filtered do
					playerEntry[queuedPlayer] = { modeId = match.modeId, status = "pending" }
				end
			end
		end
	end
end

local function launchMatch(modeId, players)
	for _, player in players do
		HubService.leaveHubForArena(player)
	end

	MatchReady:Fire(players, modeId)
	broadcastQueueUpdates()
end

local function tryLaunchMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local players = popPlayers(modeId)
	if not players then
		return
	end

	if MatchStateService.isBusy() then
		for _, player in players do
			playerEntry[player] = { modeId = modeId, status = "pending" }
		end
		table.insert(pendingMatches, { modeId = modeId, players = players })
		broadcastQueueUpdates()
		return
	end

	launchMatch(modeId, players)
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
	ffaFillEndsAt = nil
end

local function startFfaFillTimer()
	if ffaFillEndsAt then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillEndsAt = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	broadcastQueueUpdates()

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		ffaFillEndsAt = nil
		tryLaunchMode("ffa")
	end)
end

local function processArenaFreed()
	if MatchStateService.isBusy() then
		return
	end

	if #pendingMatches > 0 then
		local nextMatch = table.remove(pendingMatches, 1)
		for _, player in nextMatch.players do
			playerEntry[player] = nil
		end
		launchMatch(nextMatch.modeId, nextMatch.players)
		return
	end

	for _, mode in MatchModes.all() do
		tryLaunchMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerEntry[player] = { modeId = modeId, status = "waiting" }
	sendQueueUpdate(player)
	broadcastQueueUpdates()

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			cancelFfaFillTimer()
			tryLaunchMode("ffa")
		elseif #queue >= mode.minPlayers then
			startFfaFillTimer()
		end
	else
		tryLaunchMode(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local hadEntry = playerEntry[player] ~= nil
	removeFromQueue(player)
	removePlayerFromPending(player)

	if hadEntry then
		local ffaQueue = getQueue("ffa")
		if #ffaQueue < MatchModes.ffa.minPlayers then
			cancelFfaFillTimer()
		end
		sendQueueUpdate(player)
		broadcastQueueUpdates()
	end
end

function MatchmakingService.getSuggestedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		local resolvedMode = modeId
		if typeof(resolvedMode) ~= "string" or not MatchModes.get(resolvedMode) then
			resolvedMode = MatchmakingService.getSuggestedMode()
		end
		MatchmakingService.joinQueue(player, resolvedMode)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)

		for i = #pendingMatches, 1, -1 do
			local match = pendingMatches[i]
			local filtered = {}
			for _, queuedPlayer in match.players do
				if queuedPlayer ~= player and queuedPlayer.Parent then
					table.insert(filtered, queuedPlayer)
				end
			end
			if #filtered == 0 then
				table.remove(pendingMatches, i)
			else
				match.players = filtered
			end
		end
	end)

	MatchStateService.onArenaFreed(processArenaFreed)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
