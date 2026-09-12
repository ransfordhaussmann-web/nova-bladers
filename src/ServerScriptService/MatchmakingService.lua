local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchFlowState = require(script.Parent.MatchFlowState)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local remotes
local bindables
local queues = {}
local playerQueue = {}
local fillTokens = {}

for modeId in MatchmakingConfig.MODES do
	queues[modeId] = {}
end

local function getQueueStatus(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end

	local count = #queues[modeId]
	local status = "waiting"
	if MatchFlowState.isArenaBusy() then
		status = "pending"
	elseif modeId == "ffa" and count >= mode.minPlayers then
		status = "filling"
	elseif count >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		playersInQueue = count,
		playersNeeded = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
	}
end

local function broadcastQueue(modeId)
	local status = getQueueStatus(modeId)
	if not status then
		return
	end

	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, status)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	if modeId == "ffa" then
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	end

	broadcastQueue(modeId)
end

local function pullPlayers(modeId, count)
	local pulled = {}
	local queue = queues[modeId]
	while #pulled < count and #queue > 0 do
		local player = table.remove(queue, 1)
		if player.Parent and HubService.getPhase(player) == "hub" then
			playerQueue[player] = nil
			table.insert(pulled, player)
		end
	end
	broadcastQueue(modeId)
	return pulled
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	if modeId == "ffa" then
		fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	end

	MatchFlowState.setArenaBusy(true)
	for _, player in playerList do
		HubService.leaveHubForArena(player)
		remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			modeLabel = MatchmakingConfig.getMode(modeId).label,
			status = "starting",
			playersInQueue = #playerList,
			playersNeeded = #playerList,
			maxPlayers = #playerList,
		})
	end

	bindables.MatchReady:Fire({
		modeId = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	if MatchFlowState.isArenaBusy() then
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		return
	end

	local players = pullPlayers(modeId, mode.maxPlayers)
	startMatch(modeId, players)
end

local function scheduleFfaFill()
	local modeId = "ffa"
	local mode = MatchmakingConfig.getMode(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if MatchFlowState.isArenaBusy() then
			return
		end

		local queue = queues[modeId]
		if #queue < mode.minPlayers then
			return
		end

		local takeCount = math.min(#queue, mode.maxPlayers)
		local players = pullPlayers(modeId, takeCount)
		startMatch(modeId, players)
	end)
end

local function onQueueChanged(modeId)
	if MatchFlowState.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			local players = pullPlayers(modeId, mode.maxPlayers)
			startMatch(modeId, players)
			return
		end

		if #queue == mode.minPlayers then
			scheduleFfaFill()
		end

		broadcastQueue(modeId)
		return
	end

	if #queue >= mode.minPlayers then
		tryStartMode(modeId)
	else
		broadcastQueue(modeId)
	end
end

function MatchmakingService.init(remotesFolder, bindablesFolder)
	remotes = remotesFolder
	bindables = bindablesFolder

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	bindables.MatchEnded.Event:Connect(function()
		MatchFlowState.setArenaBusy(false)
		task.defer(function()
			for modeId in queues do
				onQueueChanged(modeId)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return
		end
		removeFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	onQueueChanged(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

return MatchmakingService
