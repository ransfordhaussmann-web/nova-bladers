local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local remotes
local matchReadyBindable
local queues = {}
local playerQueue = {}
local fillTimers = {}

local function initQueues()
	for modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if fillTimers[modeId] then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		position = position,
		pending = MatchStateService.isBusy(),
		message = MatchStateService.isBusy() and MatchmakingConfig.ARENA_BUSY_MESSAGE or nil,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 or MatchStateService.isBusy() then
		return
	end

	for _, player in playerList do
		removeFromQueue(player)
	end

	for _, player in playerList do
		HubService.enterArena(player)
	end

	matchReadyBindable:Fire({
		mode = modeId,
		players = playerList,
	})

	broadcastAllQueues()
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			if fillTimers[modeId] then
				fillTimers[modeId].cancelled = true
				fillTimers[modeId] = nil
			end
			startMatch(modeId, popPlayers(modeId, mode.maxPlayers))
			return
		end

		if fillTimers[modeId] then
			return
		end

		local token = { cancelled = false }
		fillTimers[modeId] = token
		broadcastQueueUpdate(modeId)

		task.delay(mode.fillTimeout, function()
			if token.cancelled or MatchStateService.isBusy() then
				fillTimers[modeId] = nil
				return
			end

			fillTimers[modeId] = nil
			local count = math.min(#queues[modeId], mode.maxPlayers)
			if count >= mode.minPlayers then
				startMatch(modeId, popPlayers(modeId, count))
			end
		end)
		return
	end

	local count = math.min(#queue, mode.maxPlayers)
	startMatch(modeId, popPlayers(modeId, count))
end

local function tryStartAllModes()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.get(modeId) then
		return false
	end
	if HubService.getPhase(player) == "arena" then
		return false
	end
	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId

	remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
	broadcastQueueUpdate(modeId)

	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return false
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, { left = true })
	broadcastQueueUpdate(modeId)
	return true
end

function MatchmakingService.joinRecommended(player)
	local count = #Players:GetPlayers()
	local modeId = MatchModes.recommendForPlayerCount(count)
	return MatchmakingService.joinQueue(player, modeId)
end

function MatchmakingService.onArenaFreed()
	broadcastAllQueues()
	tryStartAllModes()
end

function MatchmakingService.start(opts)
	remotes = opts.remotes
	matchReadyBindable = opts.matchReadyBindable

	initQueues()

	if opts.modePads then
		for _, pad in opts.modePads do
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "QueuePrompt"
			prompt.ActionText = MatchmakingConfig.QUEUE_JOIN_PROMPT
			prompt.ObjectText = pad.config.label
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = pad.part

			prompt.Triggered:Connect(function(player)
				MatchmakingService.joinQueue(player, pad.config.id)
			end)
		end
	end

	if opts.portalPrompt then
		opts.portalPrompt.ActionText = "Quick Match"
		opts.portalPrompt.ObjectText = "Nova Arena"
		opts.portalPrompt.Triggered:Connect(function(player)
			MatchmakingService.joinRecommended(player)
		end)
	end

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinRecommended(player)
		end
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
