--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local gatherTokens = {}
local fillTimers = {}
local onMatchReady = nil
local onQueueChanged = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function removeFromAllQueues(player)
	local mode = playerMode[player]
	if not mode then
		return
	end
	local queue = queues[mode]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end
	playerMode[player] = nil
end

local function getQueuePosition(player)
	local mode = playerMode[player]
	if not mode then
		return nil
	end
	local queue = queues[mode]
	for i, p in queue do
		if p == player then
			return i, #queue, mode
		end
	end
	return nil
end

local function buildQueuePayload(player)
	local pos, total, mode = getQueuePosition(player)
	if not pos then
		return nil
	end

	local config = getModeConfig(mode)
	local secondsLeft = nil
	if fillTimers[mode] then
		secondsLeft = math.max(0, math.ceil(fillTimers[mode].endsAt - os.clock()))
	end

	return {
		inQueue = true,
		mode = mode,
		modeLabel = config.label,
		position = pos,
		playersWaiting = total,
		playersNeeded = config.minPlayers,
		playersMax = config.maxPlayers,
		arenaBusy = MatchStateService.isArenaBusy(),
		secondsLeft = secondsLeft,
	}
end

local function broadcastQueueUpdates()
	if not onQueueChanged then
		return
	end
	for mode, queue in queues do
		for _, player in queue do
			if player.Parent then
				onQueueChanged(player, buildQueuePayload(player))
			end
		end
	end
end

local function cancelGather(mode)
	gatherTokens[mode] = (gatherTokens[mode] or 0) + 1
end

local function cancelFillTimer(mode)
	fillTimers[mode] = nil
end

local function takePlayers(mode, count)
	local queue = queues[mode]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function dispatchMatch(players, mode)
	if #players == 0 then
		return
	end
	cancelGather(mode)
	cancelFillTimer(mode)
	MatchStateService.setArenaBusy(true)
	if onMatchReady then
		onMatchReady(players, mode)
	end
end

local function scheduleGather(mode)
	local config = getModeConfig(mode)
	cancelGather(mode)
	gatherTokens[mode] = (gatherTokens[mode] or 0) + 1
	local token = gatherTokens[mode]

	task.delay(config.gatherDelay, function()
		if token ~= gatherTokens[mode] then
			return
		end
		if MatchStateService.isArenaBusy() then
			return
		end

		local queue = queues[mode]
		if #queue < config.minPlayers then
			return
		end

		local players = takePlayers(mode, config.maxPlayers)
		dispatchMatch(players, mode)
		broadcastQueueUpdates()
	end)
end

local function tryStartMode(mode)
	if MatchStateService.isArenaBusy() then
		return
	end

	local config = getModeConfig(mode)
	local queue = queues[mode]
	local count = #queue

	if count >= config.maxPlayers then
		local players = takePlayers(mode, config.maxPlayers)
		dispatchMatch(players, mode)
		broadcastQueueUpdates()
		return
	end

	if count >= config.minPlayers then
		if mode == "ffa" and config.fillTimeout and count < config.maxPlayers then
			if not fillTimers[mode] then
				fillTimers[mode] = { endsAt = os.clock() + config.fillTimeout }
				task.delay(config.fillTimeout, function()
					fillTimers[mode] = nil
					if MatchStateService.isArenaBusy() then
						return
					end
					local q = queues[mode]
					if #q >= config.minPlayers then
						scheduleGather(mode)
					end
				end)
				broadcastQueueUpdates()
			end
		else
			scheduleGather(mode)
		end
	end
end

function MatchmakingService.registerCallbacks(callbacks)
	onMatchReady = callbacks.onMatchReady
	onQueueChanged = callbacks.onQueueUpdate
end

function MatchmakingService.joinQueue(player, modeId)
	if not getModeConfig(modeId) then
		return false
	end
	if playerMode[player] == modeId then
		return true
	end

	removeFromAllQueues(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	tryStartMode(modeId)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local mode = playerMode[player]
	removeFromAllQueues(player)

	local config = getModeConfig(mode)
	local queue = queues[mode]
	if #queue < config.minPlayers then
		cancelGather(mode)
		cancelFillTimer(mode)
	end

	broadcastQueueUpdates()
end

function MatchmakingService.isInQueue(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	for mode in queues do
		tryStartMode(mode)
	end
	broadcastQueueUpdates()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromAllQueues(player)
end

MatchStateService.onArenaBusyChanged(function(busy)
	if not busy then
		return
	end
	broadcastQueueUpdates()
end)

local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.registerCallbacks({
	onMatchReady = function(players, mode)
		for _, player in players do
			HubService.enterArena(player)
		end
		Bindables.MatchReady:Fire(players, mode)
	end,
	onQueueUpdate = function(player, payload)
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = "training"
	end
	if HubService.getPhase(player) == "arena" then
		return
	end
	HubService.enterQueue(player)
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
	HubService.returnPlayerToHub(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

print("[Matchmaking] Queue system ready")

return MatchmakingService
