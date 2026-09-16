local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local remotes
local matchReadyBindable

local queues = {}
local playerMode = {}
local fillTokens = {}
local started = false

for modeId in MatchModes.all() do
	queues[modeId] = {}
end

local function getDefaultModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function countInQueue(modeId)
	return #queues[modeId]
end

local function getQueueSnapshot(modeId)
	local names = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end
	return names
end

local function buildUpdatePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queued = countInQueue(modeId)
	local arenaBusy = MatchStateService.isArenaBusy()

	local status = MatchmakingConfig.STATUS.searching
	if arenaBusy then
		status = MatchmakingConfig.STATUS.pending
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		queued = queued,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = getQueueSnapshot(modeId),
		arenaBusy = arenaBusy,
		status = status,
	}
end

local function broadcastQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local list = queues[modeId]
	for i = #list, 1, -1 do
		if list[i] == player then
			table.remove(list, i)
		end
	end
	playerMode[player] = nil

	if modeId == "ffa" and countInQueue(modeId) < MatchModes.get("ffa").minPlayers then
		fillTokens.ffa = (fillTokens.ffa or 0) + 1
	end

	broadcastQueue(modeId)
end

local function takePlayers(modeId, count)
	local list = queues[modeId]
	local taken = {}
	local limit = math.min(count, #list)
	for _ = 1, limit do
		local player = table.remove(list, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function fireMatchReady(modeId, playerList)
	for _, player in playerList do
		remotes.QueueUpdate:FireClient(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = MatchModes.get(modeId).label,
			status = MatchmakingConfig.STATUS.ready,
			queued = #playerList,
		})
	end

	matchReadyBindable:Fire({
		modeId = modeId,
		players = playerList,
	})
end

local function tryStartMode(modeId)
	if MatchStateService.isArenaBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local list = queues[modeId]

	if modeId == "training" and #list >= 1 then
		local players = takePlayers(modeId, 1)
		if #players > 0 then
			fireMatchReady(modeId, players)
			broadcastQueue(modeId)
			return true
		end
	elseif modeId == "pvp" and #list >= 2 then
		local players = takePlayers(modeId, 2)
		if #players == 2 then
			fireMatchReady(modeId, players)
			broadcastQueue(modeId)
			return true
		end
	elseif modeId == "ffa" and #list >= mode.maxPlayers then
		local players = takePlayers(modeId, mode.maxPlayers)
		if #players >= mode.minPlayers then
			fireMatchReady(modeId, players)
			broadcastQueue(modeId)
			return true
		end
	end

	return false
end

local function tryProcessQueues()
	if MatchStateService.isArenaBusy() then
		broadcastAllQueues()
		return
	end

	if tryStartMode("training") then
		return
	end
	if tryStartMode("pvp") then
		return
	end
	if tryStartMode("ffa") then
		return
	end
end

local function scheduleFfaFill()
	local mode = MatchModes.get("ffa")
	if countInQueue("ffa") < mode.minPlayers then
		return
	end

	fillTokens.ffa = (fillTokens.ffa or 0) + 1
	local token = fillTokens.ffa

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens.ffa then
			return
		end
		if MatchStateService.isArenaBusy() then
			broadcastQueue("ffa")
			return
		end

		local list = queues.ffa
		if #list >= mode.minPlayers then
			local count = math.min(#list, mode.maxPlayers)
			local players = takePlayers("ffa", count)
			if #players >= mode.minPlayers then
				fireMatchReady("ffa", players)
			end
		end
		broadcastQueue("ffa")
	end)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		modeId = getDefaultModeId()
		mode = MatchModes.get(modeId)
	end
	if not mode then
		return false
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player))
	broadcastQueue(modeId)

	if modeId == "ffa" and countInQueue("ffa") >= mode.minPlayers then
		scheduleFfaFill()
	end

	tryProcessQueues()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end
	removeFromQueue(player)
	remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.onArenaFreed()
	tryProcessQueues()
end

function MatchmakingService.start(remoteFolder, bindables)
	if started then
		return
	end
	started = true

	remotes = remoteFolder
	matchReadyBindable = bindables.MatchReady

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
