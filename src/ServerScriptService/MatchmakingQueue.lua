--[[
	MatchmakingQueue — wartende Spieler sammeln, Modus wählen, Match starten.
]]

local BeyConfig = require(game:GetService("ReplicatedStorage").NovaBladers.BeyConfig)

local MatchmakingQueue = {}

local queue = {}
local maxWait = BeyConfig.MATCH_QUEUE.MAX_WAIT_SECONDS

local function getTargetMode(count)
	local minPlayers = BeyConfig.MATCH_QUEUE.MIN_PLAYERS
	if count >= minPlayers.ffa then
		return "ffa", minPlayers.ffa
	elseif count >= minPlayers.pvp then
		return "pvp", minPlayers.pvp
	end
	return "training", minPlayers.training
end

local function findIndex(player)
	for i, entry in queue do
		if entry.player == player then
			return i
		end
	end
	return nil
end

function MatchmakingQueue.isQueued(player)
	return findIndex(player) ~= nil
end

function MatchmakingQueue.join(player)
	if findIndex(player) then
		return false
	end
	table.insert(queue, { player = player, joinedAt = os.clock() })
	return true
end

function MatchmakingQueue.leave(player)
	local idx = findIndex(player)
	if idx then
		table.remove(queue, idx)
		return true
	end
	return false
end

function MatchmakingQueue.getActivePlayers()
	local active = {}
	for i = #queue, 1, -1 do
		local entry = queue[i]
		if not entry.player.Parent then
			table.remove(queue, i)
		else
			table.insert(active, entry.player)
		end
	end
	return active
end

function MatchmakingQueue.getSnapshot()
	local players = MatchmakingQueue.getActivePlayers()
	local count = #players
	local mode, needed = getTargetMode(count)

	local oldestJoin = os.clock()
	for _, entry in queue do
		if entry.player.Parent and entry.joinedAt < oldestJoin then
			oldestJoin = entry.joinedAt
		end
	end

	local waited = count > 0 and (os.clock() - oldestJoin) or 0
	local names = {}
	for _, p in players do
		table.insert(names, p.Name)
	end

	local ready = false
	if count > 0 then
		ready = count >= needed or waited >= maxWait
	end

	return {
		count = count,
		needed = needed,
		mode = mode,
		waitedSeconds = math.floor(waited),
		maxWaitSeconds = maxWait,
		playerNames = names,
		ready = ready,
	}
end

function MatchmakingQueue.popReadyPlayers()
	local snapshot = MatchmakingQueue.getSnapshot()
	if not snapshot.ready or snapshot.count == 0 then
		return nil
	end

	local players = MatchmakingQueue.getActivePlayers()
	local _, needed = getTargetMode(#players)
	local take = needed

	if snapshot.waitedSeconds >= maxWait then
		take = math.max(1, math.min(#players, needed))
	else
		take = math.min(#players, needed)
	end

	local matchPlayers = {}
	for i = 1, take do
		table.insert(matchPlayers, players[i])
	end

	for _, p in matchPlayers do
		MatchmakingQueue.leave(p)
	end

	return matchPlayers
end

return MatchmakingQueue
