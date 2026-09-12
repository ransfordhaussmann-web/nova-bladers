local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(ReplicatedStorage.NovaBladers.MatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {}
local playerQueue = {}
local fillTokens = {}
local handlers = {}

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function modeLabel(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	return mode and mode.label or modeId
end

local function buildUpdatePayload(player, modeId, status)
	local queue = getQueue(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	return {
		modeId = modeId,
		modeLabel = modeLabel(modeId),
		status = status,
		queued = #queue,
		required = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
	}
end

local function fireUpdate(player, modeId, status)
	if player.Parent and Remotes then
		Remotes.QueueUpdate:FireClient(player, buildUpdatePayload(player, modeId, status))
	end
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		local status = MatchState.isAvailable() and "waiting" or "pending"
		fireUpdate(player, modeId, status)
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerQueue[player] = nil
	broadcastQueue(modeId)
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	broadcastQueue(modeId)
	return taken
end

local function launchMatch(modeId, playerList)
	cancelFillTimer(modeId)
	if handlers.onMatchReady then
		handlers.onMatchReady(modeId, playerList)
	end
	if MatchReady then
		MatchReady:Fire(modeId, playerList)
	end
end

local function tryStartMode(modeId)
	if not MatchState.isAvailable() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
			return
		end

		if #queue >= mode.minPlayers then
			local token = (fillTokens[modeId] or 0) + 1
			fillTokens[modeId] = token
			local timeout = mode.fillTimeout or 12

			task.delay(timeout, function()
				if fillTokens[modeId] ~= token then
					return
				end
				if not MatchState.isAvailable() then
					broadcastQueue(modeId)
					return
				end
				local current = getQueue(modeId)
				if #current >= mode.minPlayers then
					launchMatch(modeId, takePlayers(modeId, math.min(#current, mode.maxPlayers)))
				end
			end)
		end
		return
	end

	launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
end

local function onArenaAvailable()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not player or not player.Parent then
		return false
	end

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false
	end

	if playerQueue[player] then
		if playerQueue[player] == modeId then
			fireUpdate(player, modeId, MatchState.isAvailable() and "waiting" or "pending")
			return true
		end
		removeFromQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	local status = MatchState.isAvailable() and "waiting" or "pending"
	fireUpdate(player, modeId, status)
	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	if Remotes then
		Remotes.QueueUpdate:FireClient(player, { status = "left" })
	end
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.register(newHandlers)
	handlers = newHandlers or {}
end

function MatchmakingService.start()
	Remotes, _ = RemotesSetup.ensure()
	local _, bindables = RemotesSetup.ensure()
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.resolveAutoMode(#Players:GetPlayers())
		end
		if handlers.onJoinRequest then
			handlers.onJoinRequest(player, modeId)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		if handlers.onLeaveRequest then
			handlers.onLeaveRequest(player)
		else
			MatchmakingService.leaveQueue(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	MatchState.onAvailable = onArenaAvailable
end

return MatchmakingService
