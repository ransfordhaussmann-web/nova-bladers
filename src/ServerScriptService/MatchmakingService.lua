--[[
	MatchmakingService — queue players by mode and start matches when thresholds are met.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes = RemotesSetup.ensure()

local MatchmakingService = {}

local queue = {}
local queueByPlayer = {}
local onMatchReady = nil
local processing = false

local function isValidMode(modeId)
	return MatchmakingConfig.MODES[modeId] ~= nil
end

local function countByMode()
	local counts = { training = 0, pvp = 0, ffa = 0 }
	for _, entry in queue do
		if counts[entry.modeId] then
			counts[entry.modeId] += 1
		end
	end
	return counts
end

local function buildSnapshot(forPlayer)
	local counts = countByMode()
	local entry = queueByPlayer[forPlayer]
	local modeConfig = entry and MatchmakingConfig.MODES[entry.modeId]

	return {
		inQueue = entry ~= nil,
		modeId = entry and entry.modeId,
		modeLabel = modeConfig and modeConfig.label,
		counts = counts,
		queueSize = #queue,
		waitSeconds = entry and (os.clock() - entry.joinedAt),
	}
end

local function broadcastUpdate()
	local snapshot = buildSnapshot(nil)
	snapshot.counts = countByMode()
	snapshot.queueSize = #queue

	for _, player in Players:GetPlayers() do
		if player.Parent then
			local personal = buildSnapshot(player)
			Remotes.MatchmakingUpdate:FireClient(player, personal)
		end
	end
end

local function removeFromQueue(player)
	local entry = queueByPlayer[player]
	if not entry then
		return
	end

	queueByPlayer[player] = nil
	for i, queued in queue do
		if queued.player == player then
			table.remove(queue, i)
			break
		end
	end
end

local function takePlayers(modeId, count)
	local taken = {}
	local remaining = {}

	for _, entry in queue do
		if entry.modeId == modeId and #taken < count then
			table.insert(taken, entry.player)
			queueByPlayer[entry.player] = nil
		else
			table.insert(remaining, entry)
		end
	end

	queue = remaining
	return taken
end

local function startMatchForPlayers(playerList, modeId)
	if #playerList == 0 then
		return
	end

	processing = true
	local modeLabel = MatchmakingConfig.MODES[modeId].label

	for _, player in playerList do
		if player.Parent then
			Remotes.MatchmakingUpdate:FireClient(player, {
				inQueue = false,
				matchFound = true,
				modeId = modeId,
				modeLabel = modeLabel,
				counts = countByMode(),
				queueSize = #queue,
			})
			HubService.enterArena(player)
		end
	end

	broadcastUpdate()

	task.delay(MatchmakingConfig.MATCH_FOUND_DELAY, function()
		processing = false
		if onMatchReady then
			onMatchReady(playerList, modeId)
		end
	end)
end

local function tryFormMatch()
	if processing then
		return
	end

	-- FFA: 3+ players queued for FFA
	local ffaConfig = MatchmakingConfig.MODES.ffa
	local ffaCount = 0
	for _, entry in queue do
		if entry.modeId == "ffa" then
			ffaCount += 1
		end
	end
	if ffaCount >= ffaConfig.minPlayers then
		local count = math.min(ffaCount, MatchmakingConfig.MAX_FFA_PLAYERS)
		local players = takePlayers("ffa", count)
		startMatchForPlayers(players, "ffa")
		return
	end

	-- PvP: 2 players queued for PvP
	local pvpConfig = MatchmakingConfig.MODES.pvp
	local pvpCount = 0
	for _, entry in queue do
		if entry.modeId == "pvp" then
			pvpCount += 1
		end
	end
	if pvpCount >= pvpConfig.minPlayers then
		local players = takePlayers("pvp", pvpConfig.maxPlayers)
		startMatchForPlayers(players, "pvp")
		return
	end

	-- Training: solo after wait
	local now = os.clock()
	for _, entry in queue do
		if entry.modeId == "training" then
			if now - entry.joinedAt >= MatchmakingConfig.SOLO_TRAINING_WAIT then
				local players = takePlayers("training", 1)
				startMatchForPlayers(players, "training")
				return
			end
		end
	end
end

function MatchmakingService.registerOnMatch(callback)
	onMatchReady = callback
end

function MatchmakingService.join(player, modeId)
	if typeof(modeId) ~= "string" or not isValidMode(modeId) then
		return false
	end

	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	local existing = queueByPlayer[player]
	if existing and existing.modeId == modeId then
		return true
	end

	removeFromQueue(player)
	table.insert(queue, {
		player = player,
		modeId = modeId,
		joinedAt = os.clock(),
	})
	queueByPlayer[player] = queue[#queue]

	broadcastUpdate()
	tryFormMatch()
	return true
end

function MatchmakingService.leave(player)
	if not queueByPlayer[player] then
		return false
	end

	removeFromQueue(player)
	broadcastUpdate()
	return true
end

function MatchmakingService.isQueued(player)
	return queueByPlayer[player] ~= nil
end

function MatchmakingService.getMode(player)
	local entry = queueByPlayer[player]
	return entry and entry.modeId
end

-- Periodic check for solo training timeouts
RunService.Heartbeat:Connect(function()
	if #queue > 0 and not processing then
		tryFormMatch()
	end
end)

Players.PlayerRemoving:Connect(function(player)
	removeFromQueue(player)
	task.defer(broadcastUpdate)
end)

print("[MatchmakingService] Queue ready")

return MatchmakingService
