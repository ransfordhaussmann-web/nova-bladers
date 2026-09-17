local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local hubService

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromAllQueues(player)
	for modeId, queue in queues do
		for i = #queue, 1, -1 do
			if queue[i] == player then
				table.remove(queue, i)
			end
		end
		if #queue == 0 then
			fillTokens[modeId] = nil
		end
	end
	playerQueue[player] = nil
end

local function queuePosition(modeId, player)
	local queue = getQueue(modeId)
	for i, queued in queue do
		if queued == player then
			return i
		end
	end
	return 0
end

local function buildUpdate(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = queuePosition(modeId, player),
		total = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function sendUpdate(player)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildUpdate(player))
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		sendUpdate(player)
	end
end

local function leaveArenaPhase(player)
	if hubService and hubService.getPhase(player) == "arena" then
		hubService.returnToHub(player)
	end
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		removeFromAllQueues(player)
	end
	broadcastQueue(modeId)

	for _, player in playerList do
		if hubService then
			hubService.leaveHubForArena(player)
		end
	end

	MatchStateService.setBusy(true)
	MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
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

	if #queue >= mode.maxPlayers then
		local players = {}
		for i = 1, mode.maxPlayers do
			table.insert(players, queue[i])
		end
		startMatch(modeId, players)
		return
	end

	if mode.fillTimeout and #queue >= mode.minPlayers then
		if not fillTokens[modeId] then
			fillTokens[modeId] = {}
			local token = fillTokens[modeId]
			token.id = (token.id or 0) + 1
			local currentId = token.id

			task.delay(mode.fillTimeout, function()
				if fillTokens[modeId] ~= token or token.id ~= currentId then
					return
				end
				if MatchStateService.isBusy() then
					return
				end

				local currentQueue = getQueue(modeId)
				if #currentQueue < mode.minPlayers then
					fillTokens[modeId] = nil
					return
				end

				local players = {}
				for i = 1, math.min(#currentQueue, mode.maxPlayers) do
					table.insert(players, currentQueue[i])
				end
				fillTokens[modeId] = nil
				startMatch(modeId, players)
			end)
		end
		return
	end

	if not mode.fillTimeout and #queue >= mode.minPlayers then
		local players = {}
		for i = 1, mode.minPlayers do
			table.insert(players, queue[i])
		end
		startMatch(modeId, players)
	end
end

local function tryStartAll()
	for _, mode in MatchModes.getAll() do
		tryStartMode(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if playerQueue[player] == modeId then
		sendUpdate(player)
		return
	end

	removeFromAllQueues(player)
	leaveArenaPhase(player)

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMode(modeId)
end

function MatchmakingService.joinQuickMatch(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.getRecommendedForPlayerCount(count)
	MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local modeId = playerQueue[player]
	removeFromAllQueues(player)

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if mode and queue and #queue < mode.minPlayers then
		fillTokens[modeId] = nil
	end

	broadcastQueue(modeId)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.init(services)
	hubService = services
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

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

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		tryStartAll()
		for _, player in Players:GetPlayers() do
			if playerQueue[player] then
				sendUpdate(player)
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
