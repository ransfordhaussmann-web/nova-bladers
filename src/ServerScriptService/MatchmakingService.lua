--[[
	MatchmakingService — queues players by mode (training / pvp / ffa)
	and starts matches when enough players are ready.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local Remotes = RemotesSetup.ensure()

local MatchmakingService = {}

local QUEUE_CONFIG = {
	training = { minPlayers = 1, maxPlayers = 1, label = "Training", soloDelay = 2 },
	pvp = { minPlayers = 2, maxPlayers = 2, label = "1v1 PvP" },
	ffa = { minPlayers = 3, maxPlayers = 8, label = "FFA" },
}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local soloTokens = {}
local onMatchReady = nil

local function queueList(modeId)
	return queues[modeId]
end

local function removeFromQueue(player, modeId)
	local list = queues[modeId]
	for i, p in list do
		if p == player then
			table.remove(list, i)
			return true
		end
	end
	return false
end

local function buildUpdatePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local cfg = QUEUE_CONFIG[modeId]
	local list = queues[modeId]
	local names = {}
	for _, p in list do
		if p.Parent then
			table.insert(names, p.Name)
		end
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = cfg.label,
		queued = #list,
		needed = cfg.minPlayers,
		maxPlayers = cfg.maxPlayers,
		playerNames = names,
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		if player.Parent then
			Remotes.MatchmakingUpdate:FireClient(player, buildUpdatePayload(player))
		end
	end
end

local function tryStartMatch(modeId)
	local cfg = QUEUE_CONFIG[modeId]
	local list = queues[modeId]

	while #list >= cfg.minPlayers do
		local matchPlayers = {}
		local take = math.min(#list, cfg.maxPlayers)
		for _ = 1, take do
			local p = table.remove(list, 1)
			if p and p.Parent then
				table.insert(matchPlayers, p)
				playerMode[p] = nil
			end
		end

		if #matchPlayers >= cfg.minPlayers and onMatchReady then
			onMatchReady(matchPlayers, modeId)
		else
			for _, p in matchPlayers do
				table.insert(list, p)
				playerMode[p] = modeId
			end
			break
		end
	end

	broadcastQueueUpdate()
end

local function scheduleSoloStart(modeId)
	if modeId ~= "training" then
		return
	end

	soloTokens[modeId] = (soloTokens[modeId] or 0) + 1
	local token = soloTokens[modeId]

	task.delay(QUEUE_CONFIG.training.soloDelay, function()
		if token ~= soloTokens[modeId] then
			return
		end
		local list = queues[modeId]
		if #list >= QUEUE_CONFIG[modeId].minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

function MatchmakingService.setMatchCallback(callback)
	onMatchReady = callback
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.join(player, modeId)
	if not QUEUE_CONFIG[modeId] then
		return false
	end

	MatchmakingService.leave(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	broadcastQueueUpdate()

	if modeId == "training" then
		scheduleSoloStart(modeId)
	else
		tryStartMatch(modeId)
	end

	return true
end

function MatchmakingService.leave(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player, modeId)
	playerMode[player] = nil
	soloTokens[modeId] = (soloTokens[modeId] or 0) + 1

	broadcastQueueUpdate()
end

function MatchmakingService.cleanupPlayer(player)
	MatchmakingService.leave(player)
end

function MatchmakingService.getQueueSnapshot()
	local snapshot = {}
	for modeId, cfg in QUEUE_CONFIG do
		snapshot[modeId] = {
			label = cfg.label,
			queued = #queues[modeId],
			needed = cfg.minPlayers,
		}
	end
	return snapshot
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.cleanupPlayer(player)
end)

return MatchmakingService
