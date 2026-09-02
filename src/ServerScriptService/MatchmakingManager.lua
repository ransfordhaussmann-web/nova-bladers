--[[
	MatchmakingManager — lobby queue before matches start.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local StartMatch = Bindables.StartMatch

local MatchmakingManager = {}

local queue = {}
local queueIndex = {}
local deadline = 0
local running = false

local function queueCount()
	return #queue
end

local function getModeFromCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function neededPlayers(count)
	local mode = getModeFromCount(count)
	if mode == "ffa" then
		return 3
	elseif mode == "pvp" then
		return 2
	end
	return 1
end

local function secondsLeft()
	return math.max(0, math.ceil(deadline - os.clock()))
end

local function isInQueue(player)
	return queueIndex[player] ~= nil
end

local function clearQueue()
	table.clear(queue)
	table.clear(queueIndex)
	deadline = 0
end

local function removeFromQueue(player)
	local idx = queueIndex[player]
	if not idx then
		return
	end
	table.remove(queue, idx)
	queueIndex[player] = nil
	for i, p in queue do
		queueIndex[p] = i
	end
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function broadcastQueue()
	local count = queueCount()
	local payload = {
		inQueue = true,
		count = count,
		needed = neededPlayers(count),
		mode = getModeFromCount(count),
		secondsLeft = secondsLeft(),
	}
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function scheduleDeadline()
	local count = queueCount()
	if count == 0 then
		deadline = 0
		return
	end
	if count >= 3 then
		deadline = os.clock() + MatchmakingConfig.FFA_GATHER_SECONDS
	elseif count == 2 then
		deadline = os.clock() + MatchmakingConfig.GATHER_SECONDS
	else
		deadline = os.clock() + MatchmakingConfig.SOLO_TRAINING_WAIT
	end
	broadcastQueue()
end

local function preparePlayersForMatch(playerList)
	for _, player in playerList do
		if player.Parent and HubService.leaveHubForArena then
			HubService.leaveHubForArena(player)
		end
	end
end

local function startMatch()
	if running or queueCount() == 0 then
		return
	end
	running = true

	local count = queueCount()
	local maxPlayers = MatchmakingConfig.MAX_FFA_PLAYERS
	local playerList = {}
	for i = 1, math.min(count, maxPlayers) do
		local player = queue[i]
		if player and player.Parent then
			table.insert(playerList, player)
		end
	end

	clearQueue()
	preparePlayersForMatch(playerList)

	if #playerList > 0 then
		StartMatch:Fire(playerList)
	end

	running = false
end

function MatchmakingManager.enqueue(player)
	if not player or not player.Parent or isInQueue(player) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	table.insert(queue, player)
	queueIndex[player] = #queue
	scheduleDeadline()
end

function MatchmakingManager.dequeue(player)
	if not isInQueue(player) then
		return
	end
	removeFromQueue(player)
	if queueCount() > 0 then
		scheduleDeadline()
	else
		deadline = 0
	end
	broadcastQueue()
end

function MatchmakingManager.isInQueue(player)
	return isInQueue(player)
end

local function bindRemotes()
	Remotes.QueueJoin.OnServerEvent:Connect(function(player)
		MatchmakingManager.enqueue(player)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingManager.dequeue(player)
	end)

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		MatchmakingManager.enqueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingManager.dequeue(player)
	end)
end

local function startLoop()
	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			if queueCount() > 0 and deadline > 0 and os.clock() >= deadline then
				startMatch()
			elseif queueCount() > 0 and deadline > 0 then
				broadcastQueue()
			end
		end
	end)
end

function MatchmakingManager.init()
	bindRemotes()
	startLoop()
	print("[MatchmakingManager] Queue ready")
end

return MatchmakingManager
