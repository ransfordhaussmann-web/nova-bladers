local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {}
local playerQueue = {}
local fillTimers = {}
local deps = {}

local function initQueues()
	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end
end

local function getQueueCount(modeId)
	local count = 0
	for _, player in queues[modeId] do
		if player.Parent then
			count += 1
		end
	end
	return count
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local count = getQueueCount(entry.modeId)
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	end

	local payload = {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		playersInQueue = count,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}

	if entry.modeId == "ffa" and count >= mode.minPlayers and fillTimers.ffa then
		payload.fillTimeLeft = math.max(0, math.ceil(fillTimers.ffa.endsAt - os.clock()))
	end

	return payload
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueued()
	for player in playerQueue do
		if player.Parent then
			broadcastQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerQueue[player] = nil

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if modeId == "ffa" and getQueueCount("ffa") < MatchModes.ffa.minPlayers then
		fillTimers.ffa = nil
	end
end

local function pullReadyPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local ready = {}
	local queue = queues[modeId]

	for i = 1, #queue do
		local player = queue[i]
		if player.Parent and playerQueue[player] and playerQueue[player].modeId == modeId then
			table.insert(ready, player)
			if #ready >= mode.maxPlayers then
				break
			end
		end
	end

	if #ready < mode.minPlayers then
		return nil
	end

	for _, player in ready do
		removeFromQueue(player)
	end

	return ready
end

local function launchMatch(modeId, playerList)
	fillTimers[modeId] = nil
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = getQueueCount(modeId)
	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		local players = pullReadyPlayers(modeId)
		if players then
			launchMatch(modeId, players)
		end
		return
	end

	if mode.fillTimeout then
		if not fillTimers[modeId] then
			fillTimers[modeId] = {
				endsAt = os.clock() + mode.fillTimeout,
			}
			task.delay(mode.fillTimeout, function()
				fillTimers[modeId] = nil
				if MatchStateService.isArenaBusy() then
					return
				end
				local players = pullReadyPlayers(modeId)
				if players then
					launchMatch(modeId, players)
				end
			end)
		end
		return
	end

	local players = pullReadyPlayers(modeId)
	if players then
		launchMatch(modeId, players)
	end
end

local function tryAllQueues()
	for _, mode in MatchModes.all() do
		tryStartMatch(mode.id)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	if deps.leaveHubForArena then
		deps.leaveHubForArena(player)
	end

	broadcastQueueUpdate(player)
	broadcastAllQueued()
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })

	if deps.returnToHub then
		deps.returnToHub(player)
	end

	broadcastAllQueued()
end

function MatchmakingService.isInQueue(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueueMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.start(options)
	deps = options or {}
	Remotes, Bindables = RemotesSetup.ensure()
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = deps.getRecommendedMode and deps.getRecommendedMode() or "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		broadcastAllQueued()
	end)

	MatchStateService.onArenaFree(function()
		task.defer(tryAllQueues)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			broadcastAllQueued()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
