local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local ffaFillToken = {}
local started = false

for _, mode in MatchModes.all() do
	queues[mode.id] = {}
end

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function buildUpdatePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local count = getQueueCount(entry.modeId)
	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	end
end

local function broadcastQueueMode(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer)
	end
end

local function broadcastAllQueues()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
	playerQueue[player] = nil
	sendQueueUpdate(player)
	broadcastQueueMode(modeId)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(picked, player)
			playerQueue[player] = nil
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	for _, player in playerList do
		HubService.enterArena(player)
		sendQueueUpdate(player)
	end

	broadcastAllQueues()
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
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
		local players = popPlayers(modeId, mode.maxPlayers)
		startMatch(modeId, players)
		return
	end

	if modeId == "ffa" then
		return
	end

	local players = popPlayers(modeId, mode.minPlayers)
	startMatch(modeId, players)
end

local function tryStartAllModes()
	for _, mode in MatchModes.all() do
		if mode.id ~= "ffa" then
			tryStartMode(mode.id)
		end
	end

	if not MatchStateService.isBusy() then
		tryStartMode("ffa")
	end
end

local function scheduleFfaFill(modeId)
	ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
	local token = ffaFillToken[modeId]

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken[modeId] then
			return
		end
		if MatchStateService.isBusy() then
			return
		end

		local mode = MatchModes.get(modeId)
		local count = getQueueCount(modeId)
		if count < mode.minPlayers then
			return
		end

		local players = popPlayers(modeId, math.min(count, mode.maxPlayers))
		startMatch(modeId, players)
	end)
end

local function onQueueChanged(modeId)
	broadcastQueueMode(modeId)

	if modeId == "ffa" then
		local mode = MatchModes.get(modeId)
		local count = getQueueCount(modeId)
		if count >= mode.maxPlayers then
			ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
			tryStartMode(modeId)
		elseif count >= mode.minPlayers then
			scheduleFfaFill(modeId)
		else
			ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
		end
	else
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end
	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			return true
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }
	sendQueueUpdate(player)
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	if modeId == "ffa" then
		ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
	end
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
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
		broadcastAllQueues()
		tryStartAllModes()
	end)
end

return MatchmakingService
