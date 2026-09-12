local Players = game:GetService("Players")

local MatchmakingConfig = require(game:GetService("ReplicatedStorage").NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local queues = {}
local playerEntry = {}
local arenaBusy = false
local fillTokens = {}
local fillActive = {}

local callbacks = {
	onQueueUpdate = nil,
	onMatchReady = nil,
}

local function getMode(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function countValidPlayers(queue)
	local count = 0
	for _, entry in queue do
		if entry.player.Parent then
			count += 1
		end
	end
	return count
end

local function buildStatus(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = getMode(entry.modeId)
	local queue = queues[entry.modeId] or {}
	local count = countValidPlayers(queue)

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		count = count,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		pending = entry.pending,
		fillSecondsLeft = entry.fillSecondsLeft,
	}
end

local function notifyPlayer(player)
	if callbacks.onQueueUpdate and player.Parent then
		callbacks.onQueueUpdate(player, buildStatus(player))
	end
end

local function notifyMode(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, entry in queue do
		notifyPlayer(entry.player)
	end
end

local function removePlayerFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	if queue then
		for i = #queue, 1, -1 do
			if queue[i].player == player then
				table.remove(queue, i)
			end
		end
	end

	playerEntry[player] = nil
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	fillActive[modeId] = false
end

local function clearFillCountdown(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end
	for _, entry in queue do
		if playerEntry[entry.player] then
			playerEntry[entry.player].fillSecondsLeft = nil
		end
	end
end

local function popPlayers(modeId, amount)
	local queue = ensureQueue(modeId)
	local picked = {}
	local remaining = {}

	for _, entry in queue do
		if entry.player.Parent and #picked < amount then
			table.insert(picked, entry.player)
		else
			table.insert(remaining, entry)
		end
	end

	queues[modeId] = remaining
	for _, player in picked do
		playerEntry[player] = nil
	end

	return picked
end

function MatchmakingService.init(opts)
	callbacks.onQueueUpdate = opts.onQueueUpdate
	callbacks.onMatchReady = opts.onMatchReady
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
	if not busy then
		for _, modeId in MatchmakingConfig.MODE_ORDER do
			for _, entry in ensureQueue(modeId) do
				if playerEntry[entry.player] then
					playerEntry[entry.player].pending = false
				end
			end
			notifyMode(modeId)
		end
		MatchmakingService.tryStartAll()
	end
end

function MatchmakingService.getStatus(player)
	return buildStatus(player)
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		return
	end

	local modeId = playerEntry[player].modeId
	cancelFillTimer(modeId)
	removePlayerFromQueue(player)
	notifyPlayer(player)
	notifyMode(modeId)
	MatchmakingService.tryStartMode(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if playerEntry[player] then
		if playerEntry[player].modeId == modeId then
			notifyPlayer(player)
			return true
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	table.insert(queue, {
		player = player,
		joinedAt = os.clock(),
	})

	playerEntry[player] = {
		modeId = modeId,
		pending = arenaBusy,
		fillSecondsLeft = nil,
	}

	notifyPlayer(player)
	notifyMode(modeId)

	if not arenaBusy then
		MatchmakingService.tryStartMode(modeId)
	end

	return true
end

function MatchmakingService.tryStartAll()
	for _, modeId in MatchmakingConfig.MODE_ORDER do
		MatchmakingService.tryStartMode(modeId)
	end
end

function MatchmakingService.tryStartMode(modeId)
	if arenaBusy then
		return
	end

	local mode = getMode(modeId)
	local queue = queues[modeId]
	if not queue then
		return
	end

	local count = countValidPlayers(queue)
	if count == 0 then
		return
	end

	if modeId == "training" and count >= 1 then
		cancelFillTimer(modeId)
		MatchmakingService.startMatch(modeId, 1)
	elseif modeId == "pvp" and count >= 2 then
		cancelFillTimer(modeId)
		MatchmakingService.startMatch(modeId, 2)
	elseif modeId == "ffa" then
		if count >= mode.maxPlayers then
			cancelFillTimer(modeId)
			clearFillCountdown(modeId)
			MatchmakingService.startMatch(modeId, mode.maxPlayers)
		elseif count >= mode.minPlayers and not fillActive[modeId] then
			MatchmakingService.scheduleFillTimeout(modeId)
		end
	end
end

function MatchmakingService.scheduleFillTimeout(modeId)
	local mode = getMode(modeId)
	if mode.fillTimeout <= 0 or fillActive[modeId] then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]
	fillActive[modeId] = true

	task.spawn(function()
		for remaining = mode.fillTimeout, 1, -1 do
			if fillTokens[modeId] ~= token or arenaBusy then
				fillActive[modeId] = false
				return
			end

			local queue = queues[modeId]
			if not queue or countValidPlayers(queue) < mode.minPlayers then
				fillActive[modeId] = false
				return
			end

			for _, entry in queue do
				if playerEntry[entry.player] then
					playerEntry[entry.player].fillSecondsLeft = remaining
				end
			end
			notifyMode(modeId)
			task.wait(1)
		end

		fillActive[modeId] = false
		if fillTokens[modeId] ~= token or arenaBusy then
			return
		end

		local queue = queues[modeId]
		if not queue then
			return
		end

		local count = countValidPlayers(queue)
		if count >= mode.minPlayers then
			clearFillCountdown(modeId)
			MatchmakingService.startMatch(modeId, math.min(count, mode.maxPlayers))
		end
	end)
end

function MatchmakingService.startMatch(modeId, playerCount)
	if arenaBusy then
		return
	end

	local mode = getMode(modeId)
	local players = popPlayers(modeId, playerCount)
	if #players == 0 then
		return
	end

	cancelFillTimer(modeId)
	clearFillCountdown(modeId)
	arenaBusy = true

	for _, player in players do
		notifyPlayer(player)
	end
	notifyMode(modeId)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(players, modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	if playerEntry[player] then
		local modeId = playerEntry[player].modeId
		removePlayerFromQueue(player)
		notifyMode(modeId)
		MatchmakingService.tryStartMode(modeId)
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

return MatchmakingService
