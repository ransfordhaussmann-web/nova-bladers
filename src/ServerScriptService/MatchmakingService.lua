local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local Bindables
local HubService

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local pendingMatch = nil
local fillTokens = {}

local function queueContains(list, player)
	for _, queued in list do
		if queued == player then
			return true
		end
	end
	return false
end

local function removeFromList(list, player)
	for i, queued in list do
		if queued == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

local function getPlayerNames(list)
	local names = {}
	for _, player in list do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end
	return names
end

local function buildQueuePayload(modeId, forPlayer)
	local mode = MatchModes.get(modeId)
	local list = queues[modeId] or {}
	local status = "waiting"
	local statusText = MatchmakingConfig.WAITING_LABEL
	local count = #list
	local playerNames = getPlayerNames(list)

	local pendingForPlayer = pendingMatch
		and pendingMatch.modeId == modeId
		and queueContains(pendingMatch.players, forPlayer)

	if pendingForPlayer then
		status = "pending"
		statusText = MatchmakingConfig.PENDING_LABEL
		count = #pendingMatch.players
		playerNames = getPlayerNames(pendingMatch.players)
	elseif MatchStateService.isBusy() and playerQueue[forPlayer] then
		status = "pending"
		statusText = MatchmakingConfig.PENDING_LABEL
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = count,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		playerNames = playerNames,
		status = status,
		statusText = statusText,
		inQueue = forPlayer and (playerQueue[forPlayer] ~= nil or pendingForPlayer),
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end

	if pendingMatch and queueContains(pendingMatch.players, player) then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(pendingMatch.modeId, player))
		return
	end

	local info = playerQueue[player]
	if not info then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
		})
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(info.modeId, player))
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or mode.instant or not mode.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		MatchmakingService.tryStartMatch(modeId, true)
	end)
end

local function removePlayerFromQueue(player)
	local info = playerQueue[player]
	if not info then
		return
	end

	local modeId = info.modeId
	playerQueue[player] = nil
	removeFromList(queues[modeId], player)

	if pendingMatch then
		removeFromList(pendingMatch.players, player)
		if #pendingMatch.players == 0 then
			pendingMatch = nil
		end
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

local function popPlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	if not mode or #list < mode.minPlayers then
		return nil
	end

	local count = math.min(#list, mode.maxPlayers)
	local matched = {}
	for _ = 1, count do
		local player = table.remove(list, 1)
		if player and player.Parent then
			table.insert(matched, player)
			playerQueue[player] = nil
		end
	end

	if #matched < mode.minPlayers then
		for _, player in matched do
			table.insert(queues[modeId], player)
			playerQueue[player] = { modeId = modeId, joinedAt = os.clock() }
		end
		return nil
	end

	return matched
end

function MatchmakingService.tryStartMatch(modeId, forceStart)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local list = queues[modeId]
	if #list < mode.minPlayers then
		return
	end

	if mode.instant and #list < mode.maxPlayers then
		return
	end

	if not mode.instant and #list < mode.maxPlayers and not forceStart then
		return
	end

	local matched = popPlayersForMatch(modeId)
	if not matched then
		return
	end

	clearFillTimer(modeId)
	broadcastQueueUpdates()

	if MatchStateService.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = matched,
		}
		for _, player in matched do
			sendQueueUpdate(player)
		end
		return
	end

	MatchmakingService.launchMatch(matched, modeId)
end

function MatchmakingService.launchMatch(players, modeId)
	MatchStateService.setBusy(true)

	for _, player in players do
		if HubService and HubService.enterArena then
			HubService.enterArena(player)
		end
	end

	for _, player in players do
		sendQueueUpdate(player)
	end

	Bindables.MatchReady:Fire(players, modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)

	if pendingMatch then
		local nextMatch = pendingMatch
		pendingMatch = nil
		local valid = {}
		for _, player in nextMatch.players do
			if player.Parent then
				table.insert(valid, player)
			end
		end
		if #valid > 0 then
			MatchmakingService.launchMatch(valid, nextMatch.modeId)
		end
	end

	broadcastQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = {
		modeId = modeId,
		joinedAt = os.clock(),
	}

	sendQueueUpdate(player)
	broadcastQueueUpdates()

	if mode.instant then
		MatchmakingService.tryStartMatch(modeId)
	else
		if #queues[modeId] == mode.minPlayers then
			scheduleFillTimeout(modeId)
		end
		if #queues[modeId] >= mode.maxPlayers then
			clearFillTimer(modeId)
			MatchmakingService.tryStartMatch(modeId)
		end
	end

	return true
end

function MatchmakingService.joinAutoQueue(player)
	local modeId = MatchModes.resolveAuto(#Players:GetPlayers())
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removePlayerFromQueue(player)

	local mode = MatchModes.get(modeId)
	if mode and not mode.instant and #queues[modeId] < mode.minPlayers then
		clearFillTimer(modeId)
	end
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init(hubService)
	HubService = hubService
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "auto" or modeId == nil then
			MatchmakingService.joinAutoQueue(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		removePlayerFromQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
