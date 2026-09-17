local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false
local startingMatch = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getStatus(modeId, count)
	if MatchStateService.isArenaBusy() then
		return "pending"
	end
	local mode = MatchModes.get(modeId)
	if not mode then
		return "searching"
	end
	if count >= mode.minPlayers then
		return "starting"
	end
	return "searching"
end

local function buildUpdate(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local count = #queue
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = getStatus(modeId, count),
	}

	local timer = fillTimers[modeId]
	if timer and timer.endsAt then
		payload.fillSecondsLeft = math.max(0, math.ceil(timer.endsAt - os.clock()))
	end

	return payload
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildUpdate(queuedPlayer, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	fillTimers[modeId] = nil
end

local function stopFillTimer(modeId)
	clearFillTimer(modeId)
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	clearFillTimer(modeId)
	local endsAt = os.clock() + mode.fillTimeout
	fillTimers[modeId] = { endsAt = endsAt }

	task.delay(mode.fillTimeout, function()
		local timer = fillTimers[modeId]
		if not timer or timer.endsAt ~= endsAt then
			return
		end
		clearFillTimer(modeId)
		MatchmakingService.tryStartMatch(modeId)
	end)
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	local mode = MatchModes.get(modeId)
	if mode and #queue < mode.minPlayers then
		stopFillTimer(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerQueue[nextPlayer] = nil
			table.insert(picked, nextPlayer)
		end
	end
	stopFillTimer(modeId)
	broadcastQueue(modeId)
	return picked
end

function MatchmakingService.tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() or startingMatch then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local count = math.min(#queue, mode.maxPlayers)
	startingMatch = true
	local players = takePlayers(modeId, count)
	startingMatch = false
	if #players < mode.minPlayers then
		for _, pickedPlayer in players do
			MatchmakingService.joinQueue(pickedPlayer, modeId)
		end
		return
	end

	for _, queuedPlayer in players do
		Remotes.QueueUpdate:FireClient(queuedPlayer, { inQueue = false, status = "starting" })
	end

	MatchReady:Fire({
		mode = modeId,
		players = players,
	})
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			Remotes.QueueUpdate:FireClient(player, buildUpdate(player, modeId))
			return
		end
		MatchmakingService.leaveQueue(player)
	end

	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer == player then
			return
		end
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	local mode = MatchModes.get(modeId)
	if mode.fillTimeout and #queue >= mode.minPlayers and not fillTimers[modeId] then
		startFillTimer(modeId)
	end

	broadcastQueue(modeId)

	if #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif modeId == "training" and #queue >= mode.minPlayers then
		MatchmakingService.tryStartMatch(modeId)
	elseif modeId == "pvp" and #queue >= mode.maxPlayers then
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		for modeId in queues do
			local mode = MatchModes.get(modeId)
			local queue = getQueue(modeId)
			if mode and #queue >= mode.minPlayers then
				if mode.fillTimeout and not fillTimers[modeId] then
					startFillTimer(modeId)
				else
					MatchmakingService.tryStartMatch(modeId)
				end
			else
				broadcastQueue(modeId)
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
