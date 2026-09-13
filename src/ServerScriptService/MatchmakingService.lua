local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local GameMatchState = require(script.Parent.GameMatchState)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local ArenaFree = Bindables.ArenaFree

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local ffaFillDeadline = nil
local started = false
local onMatchReady = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
end

local function getPlayerName(player)
	return player.DisplayName or player.Name
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, getPlayerName(queuedPlayer))
		end
	end

	local status = "waiting"
	if GameMatchState.isBusy() then
		status = "pending"
	end

	local fillTimeLeft = nil
	if modeId == "ffa" and ffaFillDeadline then
		fillTimeLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		queueNames = names,
		status = status,
		fillTimeLeft = fillTimeLeft,
	}
end

local function broadcastQueueUpdate()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
		end
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	GameMatchState.setBusy(true)
	ffaFillToken += 1
	ffaFillDeadline = nil

	for _, player in playerList do
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "starting" })
	end

	if onMatchReady then
		onMatchReady(modeId, playerList)
	end

	MatchReady:Fire(modeId, playerList)
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end
	return #getQueue(modeId) >= mode.minPlayers
end

local function tryStartMatch(modeId)
	if GameMatchState.isBusy() then
		broadcastQueueUpdate()
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode or not canStartMode(modeId) then
		return
	end

	if modeId == "ffa" then
		local queueSize = #getQueue(modeId)
		if queueSize < mode.minPlayers then
			return
		end

		if queueSize >= mode.maxPlayers then
			ffaFillToken += 1
			ffaFillDeadline = nil
			local players = takePlayersFromQueue("ffa", mode.maxPlayers)
			launchMatch("ffa", players)
			return
		end

		if ffaFillDeadline == nil then
			ffaFillToken += 1
			local token = ffaFillToken
			ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			broadcastQueueUpdate()

			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if token ~= ffaFillToken or GameMatchState.isBusy() then
					return
				end
				if not canStartMode("ffa") then
					ffaFillDeadline = nil
					return
				end
				local count = math.min(#getQueue("ffa"), mode.maxPlayers)
				local players = takePlayersFromQueue("ffa", count)
				ffaFillDeadline = nil
				launchMatch("ffa", players)
			end)
		end
		return
	end

	local players = takePlayersFromQueue(modeId, mode.maxPlayers)
	launchMatch(modeId, players)
end

local function tryAllQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return false, "invalid_mode"
	end
	if GameMatchState.isBusy() and playerQueue[player] == modeId then
		broadcastQueueUpdate()
		return true
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	tryStartMatch(modeId)
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)

	if modeId == "ffa" and #getQueue("ffa") < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
		ffaFillDeadline = nil
	end

	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate()
	return true
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local mode = MatchModes.getRecommended(count)
	return MatchmakingService.joinQueue(player, mode.id)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	return MatchModes.getRecommended(count).id
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.setMatchReadyHandler(handler)
	onMatchReady = handler
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinRecommended(player)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		GameMatchState.setBusy(false)
		task.defer(tryAllQueues)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			if GameMatchState.isBusy() then
				broadcastQueueUpdate()
			elseif ffaFillDeadline then
				broadcastQueueUpdate()
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if not GameMatchState.isBusy() then
				tryAllQueues()
			end
		end
	end)
end

return MatchmakingService
