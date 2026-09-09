local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local initialized = false
local queues = {}
local playerQueue = {}
local fillTimers = {}
local onMatchStart

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isPlayerValid(player)
	return player and player.Parent == Players
end

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	if token then
		fillTimers[modeId] = nil
	end
	return token
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	if #queue < (getMode(modeId).minPlayers or 1) then
		clearFillTimer(modeId)
	end

	MatchmakingService.broadcastQueue(modeId)
end

local function buildUpdatePayload(modeId, player)
	local mode = getMode(modeId)
	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() and #queue >= mode.minPlayers then
		status = "pending"
	end

	return {
		modeId = modeId,
		label = mode.label,
		status = status,
		position = position,
		total = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

function MatchmakingService.broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if isPlayerValid(player) then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
		end
	end
end

local function tryStartMatch(modeId)
	local mode = getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		MatchmakingService.broadcastQueue(modeId)
		return
	end

	local matchPlayers = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matchPlayers, queue[i])
	end

	for _, player in matchPlayers do
		removeFromQueue(player)
	end

	clearFillTimer(modeId)
	MatchStateService.setArenaBusy(true)

	if onMatchStart then
		onMatchStart(matchPlayers, modeId)
	end

	Bindables.MatchReady:Fire(matchPlayers, modeId)
end

local function scheduleFillTimer(modeId)
	local mode = getMode(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	if fillTimers[modeId] then
		return
	end

	local token = {}
	fillTimers[modeId] = token

	task.delay(mode.fillTimeout, function()
		if fillTimers[modeId] ~= token then
			return
		end
		fillTimers[modeId] = nil
		tryStartMatch(modeId)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isPlayerValid(player) then
		return
	end

	modeId = modeId or MatchmakingConfig.DEFAULT_MODE
	local mode = getMode(modeId)
	if not mode then
		return
	end

	removeFromQueue(player)
	playerQueue[player] = modeId

	local queue = getQueue(modeId)
	table.insert(queue, player)

	Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(modeId, player))
	MatchmakingService.broadcastQueue(modeId)

	if #queue >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		if mode.fillTimeout then
			scheduleFillTimer(modeId)
		else
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	MatchmakingService.broadcastQueue(modeId)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.setOnMatchStart(callback)
	onMatchStart = callback
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)

	for modeId in MatchmakingConfig.MODES do
		local mode = getMode(modeId)
		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			if mode.fillTimeout and not fillTimers[modeId] then
				scheduleFillTimer(modeId)
			else
				tryStartMatch(modeId)
			end
		else
			MatchmakingService.broadcastQueue(modeId)
		end
	end
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.DEFAULT_MODE
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

MatchmakingService.init()

return MatchmakingService
