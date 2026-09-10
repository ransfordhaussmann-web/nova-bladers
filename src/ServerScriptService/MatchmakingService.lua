--[[
	MatchmakingService — server-side queue logic for Training / PvP / FFA.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerMode = {}
local fillTokens = {}
local pendingMatch = nil
local arenaBusy = false
local remotes = nil
local bindables = nil

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function isValidPlayer(player)
	return player and player.Parent
end

local function getQueueSnapshot(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end

	local players = {}
	for _, player in queues[modeId] do
		if isValidPlayer(player) then
			table.insert(players, player)
		end
	end

	return {
		modeId = modeId,
		label = mode.label,
		players = players,
		count = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
	}
end

local function sendQueueUpdate(player)
	if not remotes or not remotes.QueueUpdate then
		return
	end

	local modeId = playerMode[player]
	if not modeId then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local snapshot = getQueueSnapshot(modeId)
	if snapshot then
		remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			modeId = modeId,
			label = snapshot.label,
			count = snapshot.count,
			minPlayers = snapshot.minPlayers,
			maxPlayers = snapshot.maxPlayers,
			pending = pendingMatch ~= nil and pendingMatch.modeId == modeId,
		})
	end
end

local function broadcastQueueUpdate(modeId)
	for _, player in queues[modeId] do
		if isValidPlayer(player) then
			sendQueueUpdate(player)
		end
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	playerMode[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if #queue < MatchmakingConfig.getMode(modeId).minPlayers then
		cancelFillTimer(modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)
end

local function isArenaBusy()
	return arenaBusy
end

local function startMatch(playerList, modeId)
	if bindables and bindables.MatchReady then
		bindables.MatchReady:Fire(playerList, modeId)
	end
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local playerList = {}
	for _, player in queues[modeId] do
		if isValidPlayer(player) then
			table.insert(playerList, player)
		end
	end

	if #playerList < mode.minPlayers then
		return
	end

	if #playerList > mode.maxPlayers then
		local trimmed = {}
		for i = 1, mode.maxPlayers do
			trimmed[i] = playerList[i]
		end
		playerList = trimmed
	end

	if isArenaBusy() then
		pendingMatch = {
			players = playerList,
			modeId = modeId,
		}
		broadcastQueueUpdate(modeId)
		return
	end

	cancelFillTimer(modeId)
	startMatch(playerList, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode or mode.fillTimeout <= 0 then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if #queues[modeId] >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.configure(opts)
	remotes = opts.remotes
	bindables = opts.bindables
end

function MatchmakingService.notifyMatchStarting(playerList)
	arenaBusy = true
	if playerList then
		for _, player in playerList do
			removeFromQueue(player)
		end
	end
end

function MatchmakingService.notifyMatchEnded()
	arenaBusy = false
	MatchmakingService.onMatchEnded()
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "invalid_player"
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerMode[player] then
		if playerMode[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	sendQueueUpdate(player)
	broadcastQueueUpdate(modeId)

	if #queues[modeId] >= mode.minPlayers and #queues[modeId] >= mode.maxPlayers then
		tryStartMatch(modeId)
	elseif #queues[modeId] >= mode.minPlayers and mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
	elseif #queues[modeId] >= mode.minPlayers then
		scheduleFillTimeout(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchEnded()
	if not pendingMatch then
		return
	end

	local match = pendingMatch
	pendingMatch = nil

	local validPlayers = {}
	for _, player in match.players do
		if isValidPlayer(player) and playerMode[player] == match.modeId then
			table.insert(validPlayers, player)
		end
	end

	local mode = MatchmakingConfig.getMode(match.modeId)
	if mode and #validPlayers >= mode.minPlayers then
		startMatch(validPlayers, match.modeId)
	else
		broadcastQueueUpdate(match.modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

return MatchmakingService
