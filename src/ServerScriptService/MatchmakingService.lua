--[[
	Mode-based matchmaking queue for Training / 1v1 / FFA.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local remotes = nil
local onMatchReady = nil
local onEnterArena = nil
local matchAvailable = true

local MODE_LABELS = {
	training = "Training",
	pvp = "1v1 PvP",
	ffa = "FFA",
}

local function getRequired(mode)
	return HubConfig.MATCHMAKING_REQUIRED[mode] or 1
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.mode]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
	playerEntry[player] = nil
end

local function buildStatus(player)
	local entry = playerEntry[player]
	if not entry then
		return {
			inQueue = false,
			mode = nil,
			modeLabel = nil,
			queued = 0,
			needed = 0,
			position = 0,
			statusMessage = "Wähle einen Modus-Pad oder das Arena-Portal.",
		}
	end

	local queue = queues[entry.mode]
	local required = getRequired(entry.mode)
	local position = 0
	for i, queued in queue do
		if queued == player then
			position = i
			break
		end
	end

	local message
	if entry.mode == "training" then
		message = "Training startet..."
	elseif #queue >= required then
		message = "Match wird gestartet..."
	elseif entry.mode == "ffa" and #queue >= 2 then
		message = string.format("FFA-Warteschlange (%d/%d) — Timeout bei %ds", #queue, required, HubConfig.MATCHMAKING_FFA_TIMEOUT)
	else
		message = string.format("Warteschlange: %d/%d Spieler", #queue, required)
	end

	return {
		inQueue = true,
		mode = entry.mode,
		modeLabel = MODE_LABELS[entry.mode] or entry.mode,
		queued = #queue,
		needed = required,
		position = position,
		statusMessage = message,
	}
end

local function broadcastQueueUpdates()
	if not remotes then
		return
	end

	for player in playerEntry do
		if player.Parent then
			remotes.MatchmakingUpdate:FireClient(player, buildStatus(player))
		end
	end

	for _, player in Players:GetPlayers() do
		if player.Parent and not playerEntry[player] then
			remotes.MatchmakingUpdate:FireClient(player, buildStatus(player))
		end
	end
end

local function pullPlayers(mode, count)
	local queue = queues[mode]
	local pulled = {}
	count = math.min(count, #queue)

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(pulled, player)
		end
	end

	return pulled
end

local function tryStartMatch(mode)
	if not matchAvailable then
		return
	end
	if not onMatchReady then
		return
	end

	local queue = queues[mode]
	local required = getRequired(mode)
	if #queue < required then
		return
	end

	local count = required
	if mode == "ffa" then
		count = math.min(#queue, HubConfig.MATCHMAKING_FFA_MAX)
	end

	local players = pullPlayers(mode, count)
	if #players < required then
		for _, player in players do
			MatchmakingService.join(player, mode)
		end
		return
	end

	broadcastQueueUpdates()

	if onEnterArena then
		for _, player in players do
			onEnterArena(player)
		end
	end

	onMatchReady(players, mode)
end

function MatchmakingService.setMatchAvailable(available)
	matchAvailable = available
end

function MatchmakingService.setOnMatchReady(callback)
	onMatchReady = callback
end

function MatchmakingService.init(config)
	remotes = config.remotes
	onEnterArena = config.onEnterArena

	task.spawn(function()
		while true do
			task.wait(1)
			local ffaQueue = queues.ffa
			local required = getRequired("ffa")
			if #ffaQueue >= 2 and #ffaQueue < required then
				local oldestJoin = nil
				for _, queuedPlayer in ffaQueue do
					local entry = playerEntry[queuedPlayer]
					if entry then
						oldestJoin = oldestJoin and math.min(oldestJoin, entry.joinedAt) or entry.joinedAt
					end
				end
				if oldestJoin and os.clock() - oldestJoin >= HubConfig.MATCHMAKING_FFA_TIMEOUT then
					if matchAvailable and onMatchReady and #ffaQueue >= 2 then
						local count = math.min(#ffaQueue, HubConfig.MATCHMAKING_FFA_MAX)
						local players = pullPlayers("ffa", count)
						if #players >= 2 then
							broadcastQueueUpdates()
							if onEnterArena then
								for _, queuedPlayer in players do
									onEnterArena(queuedPlayer)
								end
							end
							onMatchReady(players, "ffa")
						end
					end
				end
			end
		end
	end)
end

function MatchmakingService.join(player, mode)
	if typeof(mode) ~= "string" or not queues[mode] then
		return false, "invalid_mode"
	end
	if playerEntry[player] then
		return false, "already_queued"
	end
	if not matchAvailable then
		return false, "match_busy"
	end
	if HubConfig.MATCHMAKING_REQUIRED[mode] == nil then
		return false, "invalid_mode"
	end

	table.insert(queues[mode], player)
	playerEntry[player] = {
		mode = mode,
		joinedAt = os.clock(),
	}

	broadcastQueueUpdates()

	if mode == "training" then
		tryStartMatch("training")
	elseif #queues[mode] >= getRequired(mode) then
		tryStartMatch(mode)
	end

	return true
end

function MatchmakingService.leave(player)
	if not playerEntry[player] then
		return false
	end
	removeFromQueue(player)
	broadcastQueueUpdates()
	return true
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.getQueueCounts()
	return {
		training = #queues.training,
		pvp = #queues.pvp,
		ffa = #queues.ffa,
	}
end

return MatchmakingService
