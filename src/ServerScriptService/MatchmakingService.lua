local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local ffaFillToken = 0
local ffaFillMode = nil
local started = false

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
end

local function getQuickMatchModeId()
	local count = #Players:GetPlayers()
	if count >= MatchmakingConfig.FFA_MIN_PLAYERS then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildQueuePayload(player, modeId)
	local entry = playerEntry[player]
	if not entry then
		return { status = "idle" }
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local needed = mode.minPlayers - #queue
	if needed < 0 then
		needed = 0
	end

	local payload = {
		status = entry.status or "waiting",
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = #queue,
		needed = needed,
		position = 0,
	}

	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			payload.position = i
			break
		end
	end

	if entry.status == "pending" then
		payload.statusText = "Arena belegt — warte auf freies Match"
	elseif entry.status == "waiting" and modeId == "ffa" and #queue >= MatchModes.ffa.minPlayers then
		payload.statusText = string.format("FFA startet bald (%d/%d)", #queue, mode.maxPlayers)
	elseif entry.status == "waiting" then
		if needed > 0 then
			payload.statusText = string.format("Warte auf %d Spieler", needed)
		else
			payload.statusText = "Match wird vorbereitet..."
		end
	end

	return payload
end

local function broadcastQueue(player)
	if not player.Parent then
		return
	end
	local entry = playerEntry[player]
	if not entry then
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, entry.modeId))
end

local function broadcastModeQueue(modeId)
	for _, player in queues[modeId] do
		broadcastQueue(player)
	end
end

local function popPlayers(modeId, count)
	local picked = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerEntry[player] = nil
		end
	end
	return picked
end

local function launchMatch(players, modeId)
	if #players == 0 then
		return
	end

	GameMatchState.setBusy(true, modeId)

	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	end

	if MatchmakingService.onMatchLaunch then
		MatchmakingService.onMatchLaunch(players, modeId)
	end

	Bindables.MatchReady:Fire({
		players = players,
		mode = modeId,
	})
end

local function tryLaunchMode(modeId)
	if GameMatchState.isBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end

	local takeCount = math.min(#queue, mode.maxPlayers)
	local players = popPlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		for i = #players, 1, -1 do
			table.insert(queue, 1, players[i])
			playerEntry[players[i]] = { modeId = modeId, status = "waiting", joinedAt = os.clock() }
		end
		return false
	end

	launchMatch(players, modeId)
	return true
end

local function markQueuePending(modeId)
	for _, player in queues[modeId] do
		if playerEntry[player] then
			playerEntry[player].status = "pending"
			broadcastQueue(player)
		end
	end
end

local function tryStartFromQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if GameMatchState.isBusy() then
		markQueuePending(modeId)
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			ffaFillToken += 1
			ffaFillMode = nil
			tryLaunchMode("ffa")
			return
		end

		if #queue >= mode.minPlayers and ffaFillMode ~= "ffa" then
			ffaFillMode = "ffa"
			ffaFillToken += 1
			local token = ffaFillToken
			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if token ~= ffaFillToken or ffaFillMode ~= "ffa" then
					return
				end
				if GameMatchState.isBusy() then
					markQueuePending("ffa")
					return
				end
				tryLaunchMode("ffa")
			end)
		end
		return
	end

	tryLaunchMode(modeId)
end

local function onArenaFree()
	task.defer(function()
		for modeId in pairs(queues) do
			for _, player in queues[modeId] do
				if playerEntry[player] and playerEntry[player].status == "pending" then
					playerEntry[player].status = "waiting"
				end
			end
			tryStartFromQueue(modeId)
		end
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerEntry[player] then
		return
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = GameMatchState.isBusy() and "pending" or "waiting",
		joinedAt = os.clock(),
	}

	broadcastModeQueue(modeId)
	tryStartFromQueue(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	MatchmakingService.joinQueue(player, getQuickMatchModeId())
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	broadcastQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })

	if modeId == "ffa" and #queues.ffa < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
		ffaFillMode = nil
	end

	broadcastModeQueue(modeId)
end

function MatchmakingService.getQueueMode(player)
	local entry = playerEntry[player]
	return entry and entry.modeId or nil
end

function MatchmakingService.isQueued(player)
	return playerEntry[player] ~= nil
end

function MatchmakingService.start(handlers)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchmakingService.onMatchLaunch = handlers and handlers.onMatchLaunch

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinQuickMatch(player)
			return
		end
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
