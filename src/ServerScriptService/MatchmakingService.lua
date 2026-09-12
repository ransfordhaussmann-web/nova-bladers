local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchFlowState = require(script.Parent.MatchFlowState)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerEntry = {}
local fillTokens = {}

for _, modeId in MatchmakingConfig.MODE_ORDER do
	queues[modeId] = {}
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildUpdatePayload(modeId, player)
	local mode = MatchmakingConfig.MODES[modeId]
	local entry = playerEntry[player]
	local queue = queues[modeId]
	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = MatchFlowState.isArenaBusy(),
		inQueue = entry ~= nil and entry.modeId == modeId,
	}
end

local function broadcastQueue(modeId)
	local queue = queues[modeId]
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildUpdatePayload(modeId, queuedPlayer))
		end
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function removePlayerFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	local mode = MatchmakingConfig.MODES[modeId]
	if #queue < mode.minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

local function popPlayersForMatch(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	local matched = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerEntry[nextPlayer] = nil
			table.insert(matched, nextPlayer)
		end
	end

	clearFillTimer(modeId)
	return matched
end

function MatchmakingService.tryStartMatches()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		MatchmakingService.tryStartMode(modeId)
	end
end

function MatchmakingService.tryStartMode(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if MatchFlowState.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if mode.fillTimeout > 0 and fillTokens[modeId] == nil then
		return
	end

	local players = popPlayersForMatch(modeId)
	if #players < mode.minPlayers then
		for _, matchedPlayer in players do
			table.insert(queue, matchedPlayer)
			playerEntry[matchedPlayer] = { modeId = modeId }
		end
		broadcastQueue(modeId)
		return
	end

	MatchFlowState.setArenaBusy(true)
	for _, matchedPlayer in players do
		HubService.leaveHubForMatch(matchedPlayer)
		Remotes.QueueUpdate:FireClient(matchedPlayer, {
			inQueue = false,
			modeId = modeId,
			modeLabel = mode.label,
		})
	end

	Bindables.MatchReady:Fire(players, modeId)
end

local function startFillTimer(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	if mode.fillTimeout <= 0 then
		MatchmakingService.tryStartMode(modeId)
		return
	end

	clearFillTimer(modeId)
	local token = fillTokens[modeId]
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		fillTokens[modeId] = nil
		MatchmakingService.tryStartMode(modeId)
	end)

	broadcastQueue(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchmakingConfig.MODES[modeId] then
		modeId = getRecommendedModeId()
	end

	if playerEntry[player] then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId }

	local mode = MatchmakingConfig.MODES[modeId]
	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))

	if #queues[modeId] >= mode.maxPlayers then
		clearFillTimer(modeId)
		fillTokens[modeId] = nil
		MatchmakingService.tryStartMode(modeId)
	elseif #queues[modeId] >= mode.minPlayers then
		if mode.fillTimeout > 0 then
			startFillTimer(modeId)
		else
			MatchmakingService.tryStartMode(modeId)
		end
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end
	removePlayerFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.onMatchEnded()
	MatchFlowState.setArenaBusy(false)
	task.defer(MatchmakingService.tryStartMatches)
end

function MatchmakingService.getRecommendedModeId()
	return getRecommendedModeId()
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
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
end

MatchmakingService.init()

return MatchmakingService
