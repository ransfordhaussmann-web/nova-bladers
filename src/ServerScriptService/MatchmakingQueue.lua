--[[
	MatchmakingQueue — server-side queue before matches start.
	Players join via Arena Portal or mode pads; match starts when enough players are ready.
]]

local Players = game:GetService("Players")

local MatchmakingQueue = {}

local MIN_PLAYERS = { training = 1, pvp = 2, ffa = 3 }
local SOLO_START_DELAY = 8
local READY_COUNTDOWN = 3

local queue = {}
local onMatchReady = nil
local broadcastUpdate = nil
local readyToken = 0
local soloToken = 0

local function getModeForCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel(mode)
	if mode == "ffa" then
		return "FFA"
	elseif mode == "pvp" then
		return "1v1 PvP"
	end
	return "Training"
end

local function getQueuedPlayers()
	local players = {}
	for _, entry in queue do
		if entry.player.Parent then
			table.insert(players, entry.player)
		end
	end
	return players
end

local function findEntry(player)
	for i, entry in queue do
		if entry.player == player then
			return entry, i
		end
	end
	return nil
end

local function cancelTimers()
	readyToken += 1
	soloToken += 1
end

local function buildPayload(forPlayer)
	local players = getQueuedPlayers()
	local count = #players
	local mode = getModeForCount(count)
	local needed = MIN_PLAYERS[mode]
	local position = 0

	for i, entry in queue do
		if entry.player == forPlayer then
			position = i
			break
		end
	end

	return {
		count = count,
		mode = mode,
		modeLabel = getModeLabel(mode),
		needed = needed,
		ready = count >= needed,
		position = position,
		inQueue = position > 0,
		countdown = nil,
	}
end

function MatchmakingQueue.configure(opts)
	if opts.onMatchReady then
		onMatchReady = opts.onMatchReady
	end
	if opts.broadcastUpdate then
		broadcastUpdate = opts.broadcastUpdate
	end
end

function MatchmakingQueue.isQueued(player)
	return findEntry(player) ~= nil
end

function MatchmakingQueue.getQueuedPlayers()
	return getQueuedPlayers()
end

function MatchmakingQueue.broadcast()
	if not broadcastUpdate then
		return
	end
	for _, entry in queue do
		if entry.player.Parent then
			broadcastUpdate(entry.player, buildPayload(entry.player))
		end
	end
end

function MatchmakingQueue.join(player, _modeHint)
	if findEntry(player) then
		return
	end

	table.insert(queue, {
		player = player,
		joinedAt = os.clock(),
	})
	MatchmakingQueue.broadcast()
	MatchmakingQueue.evaluate()
end

function MatchmakingQueue.leave(player)
	local _, index = findEntry(player)
	if not index then
		return
	end

	table.remove(queue, index)
	cancelTimers()
	MatchmakingQueue.broadcast()

	if broadcastUpdate and player.Parent then
		broadcastUpdate(player, { inQueue = false })
	end

	MatchmakingQueue.evaluate()
end

function MatchmakingQueue.clearPlayers(playerList)
	local removeSet = {}
	for _, player in playerList do
		removeSet[player] = true
	end

	for i = #queue, 1, -1 do
		if removeSet[queue[i].player] then
			table.remove(queue, i)
		end
	end

	cancelTimers()
	MatchmakingQueue.broadcast()
end

function MatchmakingQueue.evaluate()
	local players = getQueuedPlayers()
	local count = #players
	if count == 0 then
		return
	end

	local mode = getModeForCount(count)
	local needed = MIN_PLAYERS[mode]

	if count >= needed then
		MatchmakingQueue.startReadyCountdown(players, mode)
	elseif count == 1 and mode == "training" then
		MatchmakingQueue.startSoloTimer(players[1])
	end
end

function MatchmakingQueue.startSoloTimer(player)
	soloToken += 1
	local token = soloToken

	task.delay(SOLO_START_DELAY, function()
		if token ~= soloToken then
			return
		end
		if not findEntry(player) then
			return
		end
		local players = getQueuedPlayers()
		if #players == 1 and players[1] == player then
			MatchmakingQueue.startReadyCountdown(players, "training")
		end
	end)
end

function MatchmakingQueue.startReadyCountdown(players, mode)
	readyToken += 1
	local token = readyToken

	for i = READY_COUNTDOWN, 1, -1 do
		if token ~= readyToken then
			return
		end

		if broadcastUpdate then
			for _, player in players do
				if player.Parent and findEntry(player) then
					local payload = buildPayload(player)
					payload.countdown = i
					payload.ready = true
					payload.mode = mode
					payload.modeLabel = getModeLabel(mode)
					broadcastUpdate(player, payload)
				end
			end
		end

		task.wait(1)
	end

	if token ~= readyToken then
		return
	end

	local readyPlayers = {}
	for _, player in players do
		if player.Parent and findEntry(player) then
			table.insert(readyPlayers, player)
		end
	end

	if #readyPlayers == 0 then
		return
	end

	local finalMode = getModeForCount(#readyPlayers)
	if #readyPlayers < MIN_PLAYERS[finalMode] then
		MatchmakingQueue.evaluate()
		return
	end

	MatchmakingQueue.clearPlayers(readyPlayers)

	if onMatchReady then
		onMatchReady(readyPlayers, finalMode)
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.leave(player)
end)

return MatchmakingQueue
