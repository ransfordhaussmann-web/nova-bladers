local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local hubCallbacks = {}

local queues = {}
local playerQueue = {}
local pendingMatch = nil
local padCooldowns = {}

local function initQueues()
	for _, modeId in MatchModes.getAllIds() do
		queues[modeId] = {
			players = {},
			fillToken = 0,
		}
	end
end

local function getQueuePosition(player, queue)
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			return index
		end
	end
	return 0
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		position = getQueuePosition(player, queue),
		count = #queue.players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, queuedPlayer in queue.players do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue.players do
		if queuedPlayer == player then
			table.remove(queue.players, index)
			break
		end
	end

	playerQueue[player] = nil
	queue.fillToken += 1
	broadcastQueueUpdate(modeId)
end

local function leaveHubForArena(player)
	if hubCallbacks.leaveHubForArena then
		hubCallbacks.leaveHubForArena(player)
	end
end

local function returnPlayerToHub(player)
	if hubCallbacks.returnToHub then
		hubCallbacks.returnToHub(player)
	end
end

local function removeFromPending(player)
	if not pendingMatch then
		return false
	end

	for index, queuedPlayer in pendingMatch.players do
		if queuedPlayer == player then
			table.remove(pendingMatch.players, index)
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
			return true
		end
	end

	return false
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	count = math.min(count, #queue.players)

	for _ = 1, count do
		local player = table.remove(queue.players, 1)
		if player then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end

	queue.fillToken += 1
	broadcastQueueUpdate(modeId)
	return picked
end

local function tryLaunchMatch(modeId, players)
	if #players == 0 then
		return
	end

	if MatchStateService.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		for _, player in players do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					modeId = modeId,
					modeLabel = MatchModes.get(modeId).label,
					position = 1,
					count = #players,
					minPlayers = MatchModes.get(modeId).minPlayers,
					maxPlayers = MatchModes.get(modeId).maxPlayers,
					status = "pending",
				})
			end
		end
		return
	end

	MatchStateService.setBusy()
	for _, player in players do
		leaveHubForArena(player)
	end

	Bindables.MatchReady:Fire({
		modeId = modeId,
		players = players,
	})
end

local function evaluateQueue(modeId)
	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local count = #queue.players

	if count >= mode.maxPlayers then
		local players = popPlayers(modeId, mode.maxPlayers)
		tryLaunchMatch(modeId, players)
		return
	end

	if count >= mode.minPlayers and not mode.fillTimeout then
		local players = popPlayers(modeId, mode.minPlayers)
		tryLaunchMatch(modeId, players)
		return
	end

	if mode.fillTimeout and count >= mode.minPlayers then
		queue.fillToken += 1
		local token = queue.fillToken
		task.delay(mode.fillTimeout, function()
			if token ~= queue.fillToken then
				return
			end
			local current = queues[modeId]
			if #current.players < mode.minPlayers then
				return
			end
			local players = popPlayers(modeId, math.min(#current.players, mode.maxPlayers))
			tryLaunchMatch(modeId, players)
		end)
	end
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		return
	end

	removeFromQueue(player)

	local queue = queues[modeId]
	table.insert(queue.players, player)
	playerQueue[player] = modeId

	leaveHubForArena(player)
	broadcastQueueUpdate(modeId)
	evaluateQueue(modeId)
end

local function leaveQueue(player)
	local wasQueued = playerQueue[player] ~= nil
	local wasPending = removeFromPending(player)

	if not wasQueued and not wasPending then
		return
	end

	if wasQueued then
		removeFromQueue(player)
	end

	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	returnPlayerToHub(player)
end

local function flushPendingMatch()
	if not pendingMatch or MatchStateService.isBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	tryLaunchMatch(match.modeId, match.players)
end

local function onPadTouched(padConfig, hit)
	local character = hit.Parent
	if not character then
		return
	end
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return
	end

	local now = os.clock()
	if padCooldowns[player] and now - padCooldowns[player] < MatchmakingConfig.QUEUE_PAD_COOLDOWN then
		return
	end
	padCooldowns[player] = now

	joinQueue(player, padConfig.id)
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	return MatchModes.resolveFromPlayerCount(#Players:GetPlayers())
end

function MatchmakingService.init(options)
	Remotes, Bindables = RemotesSetup.ensure()
	hubCallbacks = options or {}
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	MatchStateService.onIdle(function()
		flushPendingMatch()
	end)

	if hubCallbacks.modePads then
		for _, pad in hubCallbacks.modePads do
			pad.part.Touched:Connect(function(hit)
				onPadTouched(pad.config, hit)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		padCooldowns[player] = nil
		removeFromPending(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
