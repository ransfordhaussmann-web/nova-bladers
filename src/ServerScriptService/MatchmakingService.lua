local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTokens = {}
local initialized = false

local function queueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
	return modeId
end

local function buildUpdatePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { inQueue = false }
	end

	local count = queueCount(modeId)
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queueSize = count,
		required = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = status,
	}

	if modeId == "ffa" and count >= mode.minPlayers and count < mode.maxPlayers then
		payload.fillSecondsLeft = MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	return payload
end

local function broadcastQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	for _, player in queues[modeId] do
		if player.Parent and HubService.getPhase(player) == "hub" then
			Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId))
		end
	end
end

local function broadcastLeft(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function clearFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function takePlayers(modeId, amount)
	local taken = {}
	local queue = queues[modeId]
	while #taken < amount and #queue > 0 do
		local player = table.remove(queue, 1)
		if player.Parent and HubService.getPhase(player) == "hub" then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function notifyMatchStarting(players, modeId)
	local mode = MatchModes.get(modeId)
	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = mode and mode.label or modeId,
				queueSize = #players,
				required = #players,
				status = "starting",
			})
		end
	end
end

local function launchMatch(modeId, players)
	clearFillTimer(modeId)
	notifyMatchStarting(players, modeId)

	for _, player in players do
		HubService.leaveHubForArena(player)
	end

	MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end
	if MatchStateService.isBusy() then
		return false
	end

	local count = queueCount(modeId)
	if modeId == "training" then
		return count >= 1
	elseif modeId == "pvp" then
		return count >= 2
	elseif modeId == "ffa" then
		return count >= mode.maxPlayers
	end
	return false
end

local function tryStartMatch(modeId)
	if not canStartMode(modeId) then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local players = takePlayers(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		return
	end

	launchMatch(modeId, players)
end

local function scheduleFfaFill(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or modeId ~= "ffa" then
		return
	end

	local count = queueCount(modeId)
	if count < mode.minPlayers or count >= mode.maxPlayers then
		return
	end

	clearFillTimer(modeId)
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if MatchStateService.isBusy() then
			broadcastQueue(modeId)
			return
		end

		local currentCount = queueCount(modeId)
		if currentCount >= mode.minPlayers and currentCount < mode.maxPlayers then
			local players = takePlayers(modeId, currentCount)
			if #players >= mode.minPlayers then
				launchMatch(modeId, players)
			end
		end
	end)
end

local function evaluateMode(modeId)
	if canStartMode(modeId) then
		tryStartMatch(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if modeId == "ffa" and queueCount(modeId) >= mode.minPlayers then
		scheduleFfaFill(modeId)
	end

	broadcastQueue(modeId)
end

local function evaluateAllQueues()
	for _, mode in MatchModes.all() do
		evaluateMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if MatchStateService.isBusy() and playerMode[player] == modeId then
		broadcastQueue(modeId)
		return
	end

	local previousMode = removeFromQueue(player)
	if previousMode and previousMode ~= modeId then
		broadcastQueue(previousMode)
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	evaluateMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId then
		clearFillTimer(modeId)
		broadcastQueue(modeId)
	end
	broadcastLeft(player)
end

function MatchmakingService.onArenaFreed()
	task.defer(evaluateAllQueues)
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.ARENA_RETRY_INTERVAL)
			if MatchStateService.isBusy() then
				continue
			end
			for _, mode in MatchModes.all() do
				if queueCount(mode.id) > 0 then
					evaluateMode(mode.id)
				end
			end
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
