local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local hooks = {}
local started = false

local ffaFillDeadline = nil
local ffaFillToken = 0

local function getQueueList(modeId)
	local list = queues[modeId]
	if not list then
		return {}
	end
	return list
end

local function removePlayerFromQueues(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and #queues.ffa < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end
end

local function getQueueStatus(modeId)
	if MatchStateService.isBusy() then
		return "pending"
	end

	local queue = getQueueList(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return "waiting"
	end

	if modeId == "ffa" and #queue >= mode.minPlayers and ffaFillDeadline then
		return "fill"
	end

	return "waiting"
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueueList(modeId)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = getQueueStatus(modeId),
	}

	if payload.status == "fill" and ffaFillDeadline then
		payload.fillSecondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return payload
end

local function broadcastQueue(modeId)
	local queue = getQueueList(modeId)
	for _, player in queue do
		if player.Parent then
			QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function clearQueueForPlayers(playerList)
	for _, player in playerList do
		removePlayerFromQueues(player)
		if player.Parent then
			QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
end

local function popPlayers(modeId, count)
	local queue = getQueueList(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	clearQueueForPlayers(playerList)

	if hooks.onMatchStarting then
		hooks.onMatchStarting(playerList, modeId)
	end

	MatchReady:Fire(playerList, modeId)
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueueList(modeId)
	if not mode or #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			ffaFillDeadline = nil
			ffaFillToken += 1
			startMatch(modeId, popPlayers(modeId, #queue))
			return
		end

		if not ffaFillDeadline then
			ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			ffaFillToken += 1
			local token = ffaFillToken

			task.spawn(function()
				while token == ffaFillToken and ffaFillDeadline do
					broadcastQueue("ffa")

					if os.clock() >= ffaFillDeadline then
						if not MatchStateService.isBusy() and #queues.ffa >= mode.minPlayers then
							ffaFillDeadline = nil
							startMatch("ffa", popPlayers("ffa", #queues.ffa))
						end
						break
					end

					task.wait(1)
				end
			end)
		end

		broadcastQueue("ffa")
		return
	end

	if #queue >= mode.minPlayers then
		startMatch(modeId, popPlayers(modeId, mode.minPlayers))
	end
end

local function tryStartAllQueues()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerMode[player] == modeId then
		broadcastQueue(modeId)
		return
	end

	removePlayerFromQueues(player)

	local queue = getQueueList(modeId)
	table.insert(queue, player)
	playerMode[player] = modeId

	broadcastQueue(modeId)
	tryStartMode(modeId)

	if hooks.onQueueChanged then
		hooks.onQueueChanged()
	end
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	removePlayerFromQueues(player)
	QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueue(modeId)

	if hooks.onQueueChanged then
		hooks.onQueueChanged()
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.getQueueCount(modeId)
	return #getQueueList(modeId)
end

function MatchmakingService.onArenaFree()
	MatchStateService.setBusy(false)
	tryStartAllQueues()
	broadcastAllQueues()

	if hooks.onQueueChanged then
		hooks.onQueueChanged()
	end
end

function MatchmakingService.start(serviceHooks)
	if started then
		return
	end
	started = true
	hooks = serviceHooks or {}

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
			if hooks.getDefaultMode then
				modeId = hooks.getDefaultMode()
			else
				modeId = "training"
			end
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_RECHECK_INTERVAL)
			if not MatchStateService.isBusy() then
				tryStartAllQueues()
			end
		end
	end)
end

return MatchmakingService
