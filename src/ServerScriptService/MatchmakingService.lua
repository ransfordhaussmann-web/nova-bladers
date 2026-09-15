--[[
	MatchmakingService — queue players by mode and start matches when ready.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {
	[MatchModes.Modes.Training] = {},
	[MatchModes.Modes.PvP] = {},
	[MatchModes.Modes.FFA] = {},
}

local playerQueue = {}
local fillTokens = {}

local Remotes
local MatchReady

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function removePlayerFromModeQueue(player, modeId)
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
end

local function getQueuePosition(player, modeId)
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			return i
		end
	end
	return 0
end

local function buildQueuePayload(player, modeId)
	local cfg = getModeConfig(modeId)
	local queue = queues[modeId]
	local info = playerQueue[player]
	local fillToken = fillTokens[modeId]

	return {
		mode = modeId,
		modeLabel = MatchModes.LABELS[modeId] or modeId,
		position = getQueuePosition(player, modeId),
		count = #queue,
		minPlayers = cfg.minPlayers,
		maxPlayers = cfg.maxPlayers,
		status = if MatchStateService.isArenaBusy() then "pending" elseif fillToken then "filling" else "waiting",
		arenaBusy = MatchStateService.isArenaBusy(),
		fillSecondsLeft = fillToken and math.max(0, math.ceil(fillToken.endsAt - os.clock())) or nil,
	}
end

local function sendQueueUpdate(player)
	local info = playerQueue[player]
	if not info then
		return
	end
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, info.mode))
	end
end

local function broadcastQueueUpdates()
	for player in playerQueue do
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = nil
end

local function cancelFillTimer(modeId)
	clearFillTimer(modeId)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		table.insert(picked, table.remove(queue, 1))
	end
	return picked
end

local function tryLaunchMatch(modeId, count)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local players = popPlayers(modeId, count)
	if #players == 0 then
		return false
	end

	for _, player in players do
		playerQueue[player] = nil
	end

	cancelFillTimer(modeId)
	MatchStateService.setArenaBusy(true)
	HubService.markPlayersInArena(players)
	MatchReady:Fire({
		mode = modeId,
		players = players,
	})

	broadcastQueueUpdates()
	return true
end

local function evaluateMode(modeId)
	local cfg = getModeConfig(modeId)
	local queue = queues[modeId]

	if #queue >= cfg.maxPlayers then
		tryLaunchMatch(modeId, cfg.maxPlayers)
		return
	end

	if cfg.fillTimeout <= 0 and #queue >= cfg.minPlayers then
		tryLaunchMatch(modeId, #queue)
		return
	end

	if #queue >= cfg.minPlayers and not fillTokens[modeId] then
		local token = {
			endsAt = os.clock() + cfg.fillTimeout,
		}
		fillTokens[modeId] = token

		task.delay(cfg.fillTimeout, function()
			if fillTokens[modeId] ~= token then
				return
			end
			clearFillTimer(modeId)
			if #queues[modeId] >= cfg.minPlayers then
				tryLaunchMatch(modeId, math.min(#queues[modeId], cfg.maxPlayers))
			end
		end)
	end
end

local function evaluateAllModes()
	for modeId in queues do
		evaluateMode(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local info = playerQueue[player]
	if not info then
		return
	end

	removePlayerFromModeQueue(player, info.mode)
	playerQueue[player] = nil

	local cfg = getModeConfig(info.mode)
	if #queues[info.mode] < cfg.minPlayers then
		cancelFillTimer(info.mode)
	end

	HubService.returnPlayerToHub(player)
	broadcastQueueUpdates()
	evaluateAllModes()
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { mode = modeId }

	HubService.markPlayerInQueue(player, modeId)
	sendQueueUpdate(player)
	evaluateMode(modeId)
end

function MatchmakingService.getPlayerMode(player)
	local info = playerQueue[player]
	return info and info.mode
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady
	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFreed(function()
		broadcastQueueUpdates()
		evaluateAllModes()
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			local modeId = playerQueue[player].mode
			removePlayerFromModeQueue(player, modeId)
			playerQueue[player] = nil
			local cfg = getModeConfig(modeId)
			if #queues[modeId] < cfg.minPlayers then
				cancelFillTimer(modeId)
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueueUpdates()
		end
	end)
end

function MatchmakingService.setupModePads(modePads)
	for _, pad in modePads do
		local modeId = pad.config.id
		local touched = {}

		pad.part.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end
			if touched[player] and os.clock() - touched[player] < MatchmakingConfig.PAD_TOUCH_DEBOUNCE then
				return
			end
			touched[player] = os.clock()
			MatchmakingService.joinQueue(player, modeId)
		end)
	end
end

return MatchmakingService
