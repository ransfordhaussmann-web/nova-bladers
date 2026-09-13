local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTokens = {}

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function queueCount(modeId)
	return #(queues[modeId] or {})
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { status = "idle" }
	end

	local config = getModeConfig(modeId)
	local waiting = queueCount(modeId)
	local position = 0
	for index, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	return {
		status = GameMatchState.isArenaBusy() and "pending" or "waiting",
		modeId = modeId,
		modeLabel = MatchModes.getLabel(modeId),
		position = position,
		waiting = waiting,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
	}
end

local function broadcastQueueUpdates(modeId)
	for _, player in queues[modeId] or {} do
		sendQueueUpdate(player, buildQueuePayload(player))
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerQueue[player] = nil
	sendQueueUpdate(player, { status = "idle" })
	broadcastQueueUpdates(modeId)
end

local function setPlayerPhase(player, phase)
	if HubService.setPhase then
		HubService.setPhase(player, phase)
	end
end

local function pullPlayers(modeId, count)
	local queue = queues[modeId]
	local matched = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(matched, player)
		end
	end
	return matched
end

local function startMatch(playerList, modeId)
	for _, player in playerList do
		setPlayerPhase(player, "arena")
		sendQueueUpdate(player, { status = "starting", modeId = modeId })
	end
	GameMatchState.setArenaBusy(true)
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if GameMatchState.isArenaBusy() then
		return false
	end

	local config = getModeConfig(modeId)
	local count = queueCount(modeId)
	if count < config.minPlayers then
		return false
	end

	local takeCount = math.min(count, config.maxPlayers)
	local matched = pullPlayers(modeId, takeCount)
	if #matched < config.minPlayers then
		for index, player in matched do
			table.insert(queues[modeId], index, player)
			playerQueue[player] = modeId
		end
		return false
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	startMatch(matched, modeId)
	broadcastQueueUpdates(modeId)
	return true
end

local function scheduleFillTimeout(modeId)
	local config = getModeConfig(modeId)
	if not config.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(config.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		if GameMatchState.isArenaBusy() then
			return
		end
		if queueCount(modeId) >= config.minPlayers then
			tryStartMode(modeId)
		end
	end)
end

local function tryStartAnyMode()
	for modeId in pairs(MatchmakingConfig.MODES) do
		if tryStartMode(modeId) then
			return true
		end
	end
	return false
end

local function pickQuickMatchMode()
	local bestMode = "pvp"
	local bestScore = -1

	for modeId, config in pairs(MatchmakingConfig.MODES) do
		local count = queueCount(modeId)
		if count >= config.minPlayers then
			return modeId
		end
		local score = count / config.minPlayers
		if score > bestScore then
			bestScore = score
			bestMode = modeId
		end
	end

	return bestMode
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end
	if not isValidMode(modeId) then
		return false
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			sendQueueUpdate(player, buildQueuePayload(player))
			return true
		end
		removeFromQueue(player)
	end

	local currentPhase = HubService.getPhase(player)
	if currentPhase == "arena" then
		return false
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	setPlayerPhase(player, "queued")

	local payload = buildQueuePayload(player)
	sendQueueUpdate(player, payload)
	broadcastQueueUpdates(modeId)

	local config = getModeConfig(modeId)
	if queueCount(modeId) == config.minPlayers and config.fillTimeout then
		scheduleFillTimeout(modeId)
	end

	if not GameMatchState.isArenaBusy() then
		tryStartMode(modeId)
	elseif queueCount(modeId) >= config.minPlayers then
		for _, queuedPlayer in queues[modeId] do
			sendQueueUpdate(queuedPlayer, buildQueuePayload(queuedPlayer))
		end
	end

	return true
end

function MatchmakingService.joinQuickMatch(player)
	return MatchmakingService.joinQueue(player, pickQuickMatchMode())
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		sendQueueUpdate(player, { status = "idle" })
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	setPlayerPhase(player, "hub")
end

function MatchmakingService.onArenaFree()
	tryStartAnyMode()
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
end

function MatchmakingService.onReturnToHub(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()

	for modeId in pairs(MatchmakingConfig.MODES) do
		queues[modeId] = {}
	end

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			MatchmakingService.joinQuickMatch(player)
			return
		end
		if modeId == "quick" then
			MatchmakingService.joinQuickMatch(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(function()
		MatchmakingService.onArenaFree()
	end)

	print("[MatchmakingService] Queue ready (training / pvp / ffa)")
end

return MatchmakingService
