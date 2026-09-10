local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local ffaFillToken = 0
local arenaBusy = false

local callbacks = {
	onQueueUpdate = nil,
	onMatchReady = nil,
	prepareForArena = nil,
	getPhase = nil,
}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function buildUpdate(player, status)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = #queue,
		needed = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status or "waiting",
	}
end

function MatchmakingService.configure(handlers)
	callbacks.onQueueUpdate = handlers.onQueueUpdate
	callbacks.onMatchReady = handlers.onMatchReady
	callbacks.prepareForArena = handlers.prepareForArena
	callbacks.getPhase = handlers.getPhase
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

local function broadcastUpdates()
	if callbacks.onQueueUpdate then
		callbacks.onQueueUpdate()
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return false
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, entry in queue do
		if entry.player == player then
			table.remove(queue, i)
			break
		end
	end

	if modeId == "ffa" and #queue < MatchmakingConfig.MODES.ffa.minPlayers then
		ffaFillToken += 1
	end

	broadcastUpdates()
	return true, buildUpdate(player)
end

function MatchmakingService.popReadyMatch(forceFfa)
	if pendingMatch then
		local match = pendingMatch
		pendingMatch = nil
		return match
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local mode = getMode(modeId)
		local queue = queues[modeId]
		if #queue >= mode.minPlayers then
			if modeId == "ffa" and #queue < mode.maxPlayers and not forceFfa then
				continue
			end

			local players = {}
			local count = math.min(#queue, mode.maxPlayers)
			for i = 1, count do
				local entry = table.remove(queue, 1)
				if entry and entry.player.Parent then
					table.insert(players, entry.player)
					playerQueue[entry.player] = nil
				end
			end

			if #players >= mode.minPlayers then
				return { modeId = modeId, players = players }
			end

			for _, p in players do
				MatchmakingService.joinQueue(p, modeId)
			end
		end
	end

	return nil
end

local function tryLaunchMatch(forceFfa)
	if arenaBusy then
		return
	end

	local match = MatchmakingService.popReadyMatch(forceFfa)
	if not match then
		return
	end

	if arenaBusy then
		pendingMatch = match
		broadcastUpdates()
		return
	end

	arenaBusy = true
	if callbacks.onMatchReady then
		callbacks.onMatchReady(match)
	end

	for _, player in match.players do
		if player.Parent and callbacks.prepareForArena then
			callbacks.prepareForArena(player)
		end
	end

	broadcastUpdates()
end

local function scheduleFfaFillCheck()
	if #queues.ffa < MatchmakingConfig.MODES.ffa.minPlayers then
		return
	end
	if #queues.ffa >= MatchmakingConfig.MODES.ffa.maxPlayers then
		return
	end

	local token = ffaFillToken + 1
	ffaFillToken = token
	local timeout = MatchmakingConfig.MODES.ffa.fillTimeout

	task.delay(timeout, function()
		if token ~= ffaFillToken then
			return
		end
		if #queues.ffa >= MatchmakingConfig.MODES.ffa.minPlayers then
			tryLaunchMatch(true)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getMode(modeId) then
		return false, "Ungültiger Modus"
	end

	if callbacks.getPhase and callbacks.getPhase(player) == "arena" then
		return false, "Bereits im Match"
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], { player = player, joinedAt = os.clock() })
	playerQueue[player] = modeId

	local update = buildUpdate(player, "waiting")
	broadcastUpdates()

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue >= mode.minPlayers and (modeId ~= "ffa" or #queue >= mode.maxPlayers) then
		tryLaunchMatch(false)
	elseif modeId == "ffa" and #queue >= mode.minPlayers then
		scheduleFfaFillCheck()
	end

	return true, update
end

function MatchmakingService.buildPlayerUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local status = "waiting"
	if pendingMatch then
		for _, p in pendingMatch.players do
			if p == player then
				status = "pending"
				break
			end
		end
	end

	return buildUpdate(player, status)
end

function MatchmakingService.onMatchEnded()
	arenaBusy = false
	pendingMatch = nil
	task.defer(function()
		tryLaunchMatch(false)
	end)
end

function MatchmakingService.getAllQueuedPlayers()
	local all = {}
	for player in playerQueue do
		table.insert(all, player)
	end
	return all
end

return MatchmakingService
