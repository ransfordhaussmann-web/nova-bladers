--[[
	Matchmaking queue — groups hub players by mode before arena matches start.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local Remotes, _ = RemotesSetup.ensure()

local MatchmakingService = {}

local MODES = {
	training = { minPlayers = 1, maxPlayers = 1, label = "Training", waitTimeout = 2 },
	pvp = { minPlayers = 2, maxPlayers = 2, label = "1v1 PvP", waitTimeout = 22 },
	ffa = { minPlayers = 3, maxPlayers = 8, label = "FFA", waitTimeout = 28 },
}

local queue = {}
local onMatchReady = nil
local canStartMatch = nil

local function isValidMode(modeId)
	return MODES[modeId] ~= nil
end

local function removePlayersFromQueue(players)
	local removeSet = {}
	for _, player in players do
		removeSet[player] = true
	end
	for i = #queue, 1, -1 do
		if removeSet[queue[i].player] then
			table.remove(queue, i)
		end
	end
end

local function getModeEntries(modeId)
	local entries = {}
	for _, entry in queue do
		if entry.modeId == modeId and entry.player.Parent then
			table.insert(entries, entry)
		end
	end
	table.sort(entries, function(a, b)
		return a.joinedAt < b.joinedAt
	end)
	return entries
end

local function countForMode(modeId)
	return #getModeEntries(modeId)
end

function MatchmakingService.getQueueSnapshot()
	local snapshot = {}
	for modeId, config in MODES do
		snapshot[modeId] = {
			count = countForMode(modeId),
			required = config.minPlayers,
			label = config.label,
		}
	end
	return snapshot
end

function MatchmakingService.getPlayerEntry(player)
	for _, entry in queue do
		if entry.player == player then
			return entry
		end
	end
	return nil
end

local function buildPlayerUpdate(player)
	local entry = MatchmakingService.getPlayerEntry(player)
	if not entry then
		return {
			inQueue = false,
			snapshot = MatchmakingService.getQueueSnapshot(),
		}
	end
	local config = MODES[entry.modeId]
	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = config.label,
		queuedCount = countForMode(entry.modeId),
		requiredCount = config.minPlayers,
		waitSeconds = math.floor(os.clock() - entry.joinedAt),
		snapshot = MatchmakingService.getQueueSnapshot(),
	}
end

function MatchmakingService.broadcastUpdate()
	for _, player in Players:GetPlayers() do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
		end
	end
end

function MatchmakingService.leave(player)
	for i = #queue, 1, -1 do
		if queue[i].player == player then
			table.remove(queue, i)
		end
	end
	MatchmakingService.broadcastUpdate()
end

function MatchmakingService.join(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if canStartMatch and not canStartMatch() then
		return false
	end

	MatchmakingService.leave(player)
	table.insert(queue, {
		player = player,
		modeId = modeId,
		joinedAt = os.clock(),
	})
	MatchmakingService.broadcastUpdate()
	MatchmakingService.process()
	return true
end

local function resolveTimeoutMatch(modeId, entries)
	local config = MODES[modeId]
	local count = #entries
	if count == 0 then
		return nil
	end

	local oldestWait = os.clock() - entries[1].joinedAt
	if oldestWait < config.waitTimeout then
		return nil
	end

	if modeId == "ffa" and count >= 2 then
		local players = { entries[1].player, entries[2].player }
		removePlayersFromQueue(players)
		return players, "pvp"
	end

	if count == 1 then
		local players = { entries[1].player }
		removePlayersFromQueue(players)
		return players, "training"
	end

	return nil
end

local function tryFormMatch(modeId)
	local config = MODES[modeId]
	local entries = getModeEntries(modeId)
	local count = #entries

	if count >= config.minPlayers then
		local take = math.min(count, config.maxPlayers)
		local players = {}
		for i = 1, take do
			table.insert(players, entries[i].player)
		end
		removePlayersFromQueue(players)
		return players, modeId
	end

	return resolveTimeoutMatch(modeId, entries)
end

function MatchmakingService.process()
	if not onMatchReady then
		return
	end
	if canStartMatch and not canStartMatch() then
		return
	end

	for modeId, _ in MODES do
		local result, resolvedMode = tryFormMatch(modeId)
		if result then
			local started = onMatchReady(result, resolvedMode)
			if started then
				MatchmakingService.broadcastUpdate()
				return
			else
				-- Match busy — put players back at front of queue
				for _, player in result do
					table.insert(queue, 1, {
						player = player,
						modeId = resolvedMode,
						joinedAt = os.clock(),
					})
				end
				MatchmakingService.broadcastUpdate()
				return
			end
		end
	end
end

function MatchmakingService.register(callbacks)
	onMatchReady = callbacks.onMatchReady
	canStartMatch = callbacks.canStartMatch
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leave(player)
end)

task.spawn(function()
	while true do
		MatchmakingService.process()
		task.wait(0.5)
	end
end)

return MatchmakingService
