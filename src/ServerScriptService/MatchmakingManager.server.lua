local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

local queues = {}
local playerQueue = {}
local arenaBusy = false
local fillTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
	fillTokens[modeId] = 0
end

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function countValidPlayers(modeId)
	local count = 0
	for _, player in queues[modeId] do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function buildQueuePayload(modeId)
	local mode = getModeConfig(modeId)
	local players = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(players, player.Name)
		end
	end
	return {
		modeId = modeId,
		label = mode.label,
		players = players,
		count = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = arenaBusy,
	}
end

local function broadcastQueueUpdate(modeId)
	local payload = buildQueuePayload(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerQueue[player] = nil
	broadcastQueueUpdate(modeId)
end

local function popPlayers(modeId, amount)
	local picked = {}
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		local player = queue[i]
		if player.Parent and #picked < amount then
			table.insert(picked, 1, player)
			table.remove(queue, i)
			playerQueue[player] = nil
		elseif not player.Parent then
			table.remove(queue, i)
			playerQueue[player] = nil
		end
	end
	return picked
end

local function notifyPlayersLeftQueue(players)
	for _, player in players do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = nil,
				label = "",
				players = {},
				count = 0,
				minPlayers = 0,
				maxPlayers = 0,
				pending = false,
				left = true,
			})
		end
	end
end

local function tryStartMatch(modeId)
	if arenaBusy then
		return
	end

	local mode = getModeConfig(modeId)
	local count = countValidPlayers(modeId)
	if count < mode.minPlayers then
		return
	end

	local takeCount = math.min(count, mode.maxPlayers)
	local players = popPlayers(modeId, takeCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		broadcastQueueUpdate(modeId)
		return
	end

	fillTokens[modeId] += 1
	notifyPlayersLeftQueue(players)
	Bindables.MatchReady:Fire(players, modeId)
end

local function scheduleFillCheck(modeId)
	local mode = getModeConfig(modeId)
	if mode.fillTimeout <= 0 then
		tryStartMatch(modeId)
		return
	end

	fillTokens[modeId] += 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		tryStartMatch(modeId)
	end)
end

local function onQueueChanged(modeId)
	broadcastQueueUpdate(modeId)

	local mode = getModeConfig(modeId)
	local count = countValidPlayers(modeId)

	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if count >= mode.minPlayers then
		scheduleFillCheck(modeId)
	elseif count > 0 and modeId == "training" then
		tryStartMatch(modeId)
	end
end

local function joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		return true
	end

	clearPlayerFromQueues(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId))
	onQueueChanged(modeId)
	return true
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end
	clearPlayerFromQueues(player)
	Remotes.QueueUpdate:FireClient(player, {
		modeId = nil,
		left = true,
	})
end

local function getQueueState(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end
	return buildQueuePayload(modeId)
end

local function setArenaBusy(busy)
	arenaBusy = busy
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
	if not busy then
		for modeId in queues do
			if countValidPlayers(modeId) > 0 then
				onQueueChanged(modeId)
			end
		end
	end
end

local function requeuePlayers(playerList, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return
	end
	for _, player in playerList do
		if player.Parent and not playerQueue[player] then
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
	end
	onQueueChanged(modeId)
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Bindables.MatchStarted.Event:Connect(function()
	setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	setArenaBusy(false)
end)

Players.PlayerRemoving:Connect(function(player)
	leaveQueue(player)
end)

MatchmakingService.register({
	joinQueue = joinQueue,
	leaveQueue = leaveQueue,
	getQueueState = getQueueState,
	setArenaBusy = setArenaBusy,
	requeuePlayers = requeuePlayers,
})

print("[MatchmakingManager] Queue system ready")
