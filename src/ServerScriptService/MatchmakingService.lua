local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerMode = {}
local pendingPlayers = {}
local fillTimers = {}
local started = false

for _, modeId in MatchModes.all() do
	queues[modeId] = {}
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId or pendingPlayers[player] then
		pendingPlayers[player] = nil
		playerMode[player] = nil
		return modeId
	end

	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil
	return modeId
end

local function cancelFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function getPlayerPosition(player, modeId)
	if pendingPlayers[player] then
		return 0
	end
	local queue = queues[modeId]
	for i, p in queue do
		if p == player then
			return i
		end
	end
	return 0
end

local function buildStatus(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)
	local position = getPlayerPosition(player, modeId)
	local status = "waiting"

	if pendingPlayers[player] then
		status = "arena_busy"
	elseif GameMatchState.isArenaBusy() and count >= mode.minPlayers then
		status = "arena_busy"
	elseif modeId == "ffa" and count >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	elseif count >= mode.maxPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		status = status,
		fillSecondsLeft = fillTimers[modeId] and fillTimers[modeId].secondsLeft,
	}
end

local function sendStatus(player)
	if not player.Parent then
		return
	end
	local payload = buildStatus(player)
	if payload then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		sendStatus(player)
	end
	for player in pendingPlayers do
		if playerMode[player] == modeId then
			sendStatus(player)
		end
	end
end

local function pullRoster(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = math.min(#queue, mode.maxPlayers)
	if count < mode.minPlayers then
		return nil
	end

	local roster = {}
	for i = 1, count do
		table.insert(roster, queue[i])
	end

	for i = count, 1, -1 do
		local player = queue[i]
		table.remove(queue, i)
	end

	cancelFillTimer(modeId)
	return roster
end

local function launchMatch(roster, modeId)
	GameMatchState.setArenaBusy(true)
	for _, player in roster do
		pendingPlayers[player] = nil
		playerMode[player] = nil
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				modeLabel = MatchModes.get(modeId).label,
				status = "starting",
			})
		end
	end
	Bindables.MatchReady:Fire(roster, modeId)
end

local function holdForArena(roster, modeId)
	GameMatchState.enqueuePending({ players = roster, modeId = modeId })
	for _, player in roster do
		playerMode[player] = modeId
		pendingPlayers[player] = true
	end
	broadcastQueue(modeId)
end

function MatchmakingService.tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)

	if count < mode.minPlayers then
		return
	end

	if mode.fillTimeout > 0 and count < mode.maxPlayers then
		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token
			token.secondsLeft = mode.fillTimeout

			task.spawn(function()
				while token.secondsLeft and token.secondsLeft > 0 do
					task.wait(1)
					if fillTimers[modeId] ~= token then
						return
					end
					token.secondsLeft -= 1
					broadcastQueue(modeId)
				end

				if fillTimers[modeId] ~= token then
					return
				end
				fillTimers[modeId] = nil

				if getQueueCount(modeId) >= mode.minPlayers then
					MatchmakingService.tryStartMatch(modeId)
				end
			end)
		end
		broadcastQueue(modeId)
		return
	end

	local roster = pullRoster(modeId)
	if not roster then
		return
	end

	if GameMatchState.isArenaBusy() then
		holdForArena(roster, modeId)
		return
	end

	launchMatch(roster, modeId)
	for _, otherModeId in MatchModes.all() do
		if otherModeId ~= modeId then
			broadcastQueue(otherModeId)
		end
	end
end

local function tryStartAllModes()
	for _, modeId in MatchModes.all() do
		MatchmakingService.tryStartMatch(modeId)
	end
end

local function onArenaFree()
	if GameMatchState.hasPending() then
		local pending = GameMatchState.dequeuePending()
		local roster = {}
		for _, player in pending.players do
			if player.Parent then
				table.insert(roster, player)
			else
				pendingPlayers[player] = nil
				playerMode[player] = nil
			end
		end
		if #roster > 0 then
			launchMatch(roster, pending.modeId)
		else
			GameMatchState.setArenaBusy(false)
			tryStartAllModes()
		end
		return
	end

	GameMatchState.setArenaBusy(false)
	tryStartAllModes()
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return
	end

	local previousMode = removeFromQueue(player)
	playerMode[player] = modeId
	table.insert(queues[modeId], player)

	if previousMode and previousMode ~= modeId then
		broadcastQueue(previousMode)
	end

	sendStatus(player)
	MatchmakingService.tryStartMatch(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local counts = {}
	for _, modeId in MatchModes.all() do
		counts[modeId] = getQueueCount(modeId)
	end

	if counts.pvp >= 1 then
		MatchmakingService.joinQueue(player, "pvp")
	elseif counts.ffa >= 2 then
		MatchmakingService.joinQueue(player, "ffa")
	elseif #Players:GetPlayers() >= 3 then
		MatchmakingService.joinQueue(player, "ffa")
	elseif #Players:GetPlayers() >= 2 then
		MatchmakingService.joinQueue(player, "pvp")
	else
		MatchmakingService.joinQueue(player, "training")
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	pendingPlayers[player] = nil
	if modeId then
		cancelFillTimer(modeId)
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
		broadcastQueue(modeId)
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
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
end

return MatchmakingService
