local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerEntry = {}
local pendingMatches = {}
local ffaFillToken = 0

local function getModeConfig(modeId)
	return MatchmakingConfig.getMode(modeId)
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function queueSize(modeId)
	local list = queues[modeId]
	return list and #list or 0
end

local function findPlayerInQueue(player)
	return playerEntry[player]
end

local function buildUpdatePayload(player, entry)
	if not entry then
		return { inQueue = false }
	end

	local mode = getModeConfig(entry.modeId)
	local size = queueSize(entry.modeId)
	if entry.status == "pending" then
		for _, match in pendingMatches do
			for _, queuedPlayer in match.players do
				if queuedPlayer == player then
					size = #match.players
					break
				end
			end
		end
	end
	return {
		inQueue = true,
		mode = entry.modeId,
		modeLabel = mode.label,
		players = size,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = entry.status or "waiting",
	}
end

local function broadcastQueueUpdate(targetPlayer)
	local entry = findPlayerInQueue(targetPlayer)
	Remotes.QueueUpdate:FireClient(targetPlayer, buildUpdatePayload(targetPlayer, entry))
end

local function broadcastAllQueued()
	for player in playerEntry do
		if player.Parent then
			broadcastQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local list = queues[entry.modeId]
	if list then
		for i, queuedPlayer in list do
			if queuedPlayer == player then
				table.remove(list, i)
				break
			end
		end
	end

	playerEntry[player] = nil
	HubService.clearQueue(player)
end

local function addToQueue(player, modeId)
	removeFromQueue(player)

	local list = queues[modeId]
	table.insert(list, player)
	playerEntry[player] = {
		modeId = modeId,
		status = "waiting",
	}
	HubService.enterQueue(player, modeId)
end

local function takePlayers(modeId, count)
	local list = queues[modeId]
	local taken = {}
	local limit = math.min(count, #list)

	for _ = 1, limit do
		local player = table.remove(list, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerEntry[player] = nil
		end
	end

	return taken
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function removePlayerFromPending(player)
	for i, match in pendingMatches do
		for j, queuedPlayer in match.players do
			if queuedPlayer == player then
				table.remove(match.players, j)
				local mode = getModeConfig(match.modeId)
				if #match.players < mode.minPlayers then
					for _, survivor in match.players do
						if survivor.Parent then
							addToQueue(survivor, match.modeId)
						end
					end
					table.remove(pendingMatches, i)
				end
				return
			end
		end
	end
end

local function launchMatch(players, modeId)
	local mode = getModeConfig(modeId)
	local valid = {}
	for _, player in players do
		if player.Parent then
			table.insert(valid, player)
		end
	end

	if #valid < mode.minPlayers then
		for _, player in valid do
			addToQueue(player, modeId)
		end
		return
	end

	cancelFfaFillTimer()
	for _, player in valid do
		playerEntry[player] = nil
	end
	Bindables.MatchReady:Fire(valid, modeId)
end

local function scheduleFfaFill()
	local mode = getModeConfig("ffa")
	if not mode or not mode.fillTimeout then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(mode.fillTimeout, function()
		if token ~= ffaFillToken then
			return
		end
		if queueSize("ffa") >= mode.minPlayers then
			MatchmakingService.tryStartMatch("ffa")
		end
	end)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local size = queueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	local takeCount = math.min(size, mode.maxPlayers)
	local players = takePlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		for _, player in players do
			addToQueue(player, modeId)
		end
		return
	end

	if GameMatchState.isBusy() then
		for _, player in players do
			playerEntry[player] = {
				modeId = modeId,
				status = "pending",
			}
		end
		table.insert(pendingMatches, {
			modeId = modeId,
			players = players,
		})
		broadcastAllQueued()
		return
	end

	launchMatch(players, modeId)
end

local function launchPendingMatch(match)
	launchMatch(match.players, match.modeId)
end

local function evaluateMode(modeId)
	local mode = getModeConfig(modeId)
	if not mode then
		return
	end

	local size = queueSize(modeId)
	if size < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if size >= mode.maxPlayers then
			MatchmakingService.tryStartMatch("ffa")
		elseif size == mode.minPlayers then
			scheduleFfaFill()
		end
		return
	end

	MatchmakingService.tryStartMatch(modeId)
end

local function evaluateAllModes()
	for modeId in queues do
		evaluateMode(modeId)
	end
end

local function onArenaFree()
	if #pendingMatches > 0 then
		local match = table.remove(pendingMatches, 1)
		if GameMatchState.isBusy() then
			table.insert(pendingMatches, 1, match)
			return
		end
		for _, player in match.players do
			if player.Parent then
				playerEntry[player] = {
					modeId = match.modeId,
					status = "pending",
				}
			end
		end
		broadcastAllQueued()
		launchPendingMatch(match)
		return
	end

	evaluateAllModes()
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if GameMatchState.isBusy() and findPlayerInQueue(player) then
		return
	end

	addToQueue(player, modeId)
	broadcastQueueUpdate(player)
	evaluateMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not findPlayerInQueue(player) then
		return
	end

	removePlayerFromPending(player)
	removeFromQueue(player)
	broadcastQueueUpdate(player)

	if queueSize("ffa") < getModeConfig("ffa").minPlayers then
		cancelFfaFillTimer()
	end
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local modeId = MatchmakingConfig.recommendMode(count)
	MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()

	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinRecommended(player)
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
