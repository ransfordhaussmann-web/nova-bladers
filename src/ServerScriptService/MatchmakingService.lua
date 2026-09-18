local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local pendingMatch = nil
local handlers = {}

local function getMode(modeId)
	return MatchModes[modeId]
end

local function buildQueuePayload(modeId, position)
	local mode = getMode(modeId)
	local queue = queues[modeId] or {}
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		fillTimeout = mode and mode.fillTimeout,
		position = position,
		pending = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	for index, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(modeId, index))
		end
	end
end

local function removePlayerFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil
	broadcastQueueUpdate(modeId)
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}

	for _ = 1, count do
		local nextPlayer = queue[1]
		if not nextPlayer then
			break
		end
		table.remove(queue, 1)
		playerQueue[nextPlayer] = nil
		table.insert(taken, nextPlayer)
	end

	broadcastQueueUpdate(modeId)
	return taken
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = nil
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	local token = {}
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTokens[modeId] = nil

		local queue = queues[modeId]
		if #queue >= mode.minPlayers then
			local count = math.min(#queue, mode.maxPlayers)
			MatchmakingService.tryStartMatch(modeId, count)
		end
	end)
end

function MatchmakingService.tryStartMatch(modeId, playerCount)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not mode or not queue or #queue < mode.minPlayers then
		return
	end

	local count = playerCount or mode.maxPlayers
	count = math.min(count, #queue, mode.maxPlayers)
	count = math.max(count, mode.minPlayers)

	if count < mode.minPlayers then
		return
	end

	local players = takePlayersFromQueue(modeId, count)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		broadcastQueueUpdate(modeId)
		return
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		for _, player in players do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					modeId = modeId,
					modeLabel = mode.label,
					count = #players,
					minPlayers = mode.minPlayers,
					maxPlayers = mode.maxPlayers,
					pending = true,
				})
			end
		end
		return
	end

	cancelFillTimer(modeId)

	if handlers.onMatchReady then
		for _, player in players do
			handlers.onMatchReady(player, modeId)
		end
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

local function evaluateQueue(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not mode or not queue then
		return
	end

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId, mode.maxPlayers)
		return
	end

	if mode.fillTimeout then
		if #queue >= mode.minPlayers and not fillTokens[modeId] then
			scheduleFillTimer(modeId)
		end
		return
	end

	if #queue >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId, mode.minPlayers)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not getMode(modeId) then
		return false
	end

	if playerQueue[player] == modeId then
		return true
	end

	MatchmakingService.leaveQueue(player)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if handlers.onJoinQueue then
		handlers.onJoinQueue(player, modeId)
	end

	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	removePlayerFromQueue(player)

	if handlers.onLeaveQueue then
		handlers.onLeaveQueue(player)
	end
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}

	for modeId in MatchModes do
		queues[modeId] = {}
	end

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		if not pendingMatch then
			return
		end

		local match = pendingMatch
		pendingMatch = nil

		if MatchStateService.isArenaBusy() then
			return
		end

		if handlers.onMatchReady then
			for _, player in match.players do
				if player.Parent then
					handlers.onMatchReady(player, match.modeId)
				end
			end
		end

		MatchReady:Fire({
			mode = match.modeId,
			players = match.players,
		})
	end)
end

return MatchmakingService
