local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local ffaReadySince = nil
local running = false

for _, mode in MatchModes.all() do
	queues[mode.id] = {}
end

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function getQueueSize(modeId)
	local queue = queues[modeId]
	if not queue then
		return 0
	end
	local count = 0
	for _, player in queue do
		if isValidPlayer(player) then
			count += 1
		end
	end
	return count
end

local function compactQueue(modeId)
	local queue = queues[modeId]
	local compact = {}
	for _, player in queue do
		if isValidPlayer(player) then
			table.insert(compact, player)
		else
			playerQueue[player] = nil
		end
	end
	queues[modeId] = compact
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local size = getQueueSize(modeId)
	local pending = MatchStateService.isArenaBusy()
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		queueSize = size,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		pending = pending,
		inQueue = player ~= nil,
	}
end

local function broadcastQueueUpdate(modeId)
	compactQueue(modeId)
	for _, player in queues[modeId] do
		if isValidPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for _, mode in MatchModes.all() do
		broadcastQueueUpdate(mode.id)
	end
end

local function removeFromAllQueues(player, exceptModeId)
	for modeId, queue in queues do
		if modeId ~= exceptModeId then
			for i = #queue, 1, -1 do
				if queue[i] == player then
					table.remove(queue, i)
				end
			end
		end
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	if modeId == "ffa" and getQueueSize("ffa") < MatchModes.ffa.minPlayers then
		ffaReadySince = nil
	end

	Remotes.QueueUpdate:FireClient(player, {
		modeId = modeId,
		inQueue = false,
	})
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false, "invalid_player"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if MatchmakingService.getPlayerQueue(player) == modeId then
		broadcastQueueUpdate(modeId)
		return true
	end

	MatchmakingService.leaveQueue(player)
	removeFromAllQueues(player, modeId)

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	if modeId == "ffa" and getQueueSize("ffa") >= mode.minPlayers and not ffaReadySince then
		ffaReadySince = os.clock()
	end

	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

local function popQueuePlayers(modeId, count)
	compactQueue(modeId)
	local queue = queues[modeId]
	local picked = {}
	for i = 1, math.min(count, #queue) do
		local player = queue[1]
		table.remove(queue, 1)
		playerQueue[player] = nil
		table.insert(picked, player)
	end
	return picked
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	compactQueue(modeId)
	local size = getQueueSize(modeId)
	if size < mode.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if size >= mode.maxPlayers then
			-- full — start immediately
		elseif ffaReadySince and (os.clock() - ffaReadySince) >= MatchmakingConfig.FFA_FILL_TIMEOUT then
			-- timed start with whoever is waiting
		else
			return false
		end
	end

	local playerCount = math.min(size, mode.maxPlayers)
	local players = popQueuePlayers(modeId, playerCount)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerQueue[player] = modeId
		end
		return false
	end

	if modeId == "ffa" then
		ffaReadySince = nil
	end

	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(players, modeId)
	broadcastAllQueues()
	return true
end

local function evaluateQueues()
	if MatchStateService.isArenaBusy() then
		broadcastAllQueues()
		return
	end

	for _, mode in MatchModes.all() do
		if tryStartMode(mode.id) then
			break
		end
	end
end

function MatchmakingService.start()
	if running then
		return
	end
	running = true

	MatchStateService.onArenaBusyChanged(function(busy)
		if not busy then
			task.defer(evaluateQueues)
		else
			broadcastAllQueues()
		end
	end)

	task.spawn(function()
		while running do
			evaluateQueues()
			task.wait(MatchmakingConfig.QUEUE_TICK)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
