local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local started = false
local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	if fillTimers[modeId] and #queue < (MatchModes.get(modeId).minPlayers or 1) then
		fillTimers[modeId].cancelled = true
		fillTimers[modeId] = nil
	end
end

local function queueStatus(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif count >= mode.maxPlayers then
		status = "ready"
	elseif count >= mode.minPlayers and not mode.fillTimeout then
		status = "ready"
	elseif count >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		arenaBusy = MatchStateService.isArenaBusy(),
		fillSecondsLeft = fillTimers[modeId] and fillTimers[modeId].secondsLeft,
	}
end

local function buildPlayerUpdate(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local queue = getQueue(modeId)
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = queueStatus(modeId)
	return {
		inQueue = true,
		position = position,
		modeId = modeId,
		modeLabel = status.modeLabel,
		count = status.count,
		minPlayers = status.minPlayers,
		maxPlayers = status.maxPlayers,
		queueStatus = status.status,
		arenaBusy = status.arenaBusy,
		fillSecondsLeft = status.fillSecondsLeft,
	}
end

local function broadcastQueue(modeId)
	local status = queueStatus(modeId)
	for _, player in getQueue(modeId) do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player), status)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function takePlayers(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerMode[player] = nil
		end
	end
	return taken
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	fillTimers[modeId] = nil
	MatchStateService.setArenaBusy(true)
	MatchReady:Fire(players, modeId)
	broadcastAllQueues()
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	if count >= mode.maxPlayers then
		launchMatch(modeId, takePlayers(modeId, mode.maxPlayers))
		return
	end

	if mode.fillTimeout and count >= mode.minPlayers then
		if not fillTimers[modeId] then
			local timerState = { cancelled = false, secondsLeft = mode.fillTimeout }
			fillTimers[modeId] = timerState

			task.spawn(function()
				for remaining = mode.fillTimeout, 1, -1 do
					if timerState.cancelled or fillTimers[modeId] ~= timerState then
						return
					end
					timerState.secondsLeft = remaining
					broadcastQueue(modeId)
					task.wait(1)
				end

				if timerState.cancelled or fillTimers[modeId] ~= timerState then
					return
				end
				if MatchStateService.isArenaBusy() then
					broadcastQueue(modeId)
					return
				end

				local readyCount = #getQueue(modeId)
				if readyCount >= mode.minPlayers then
					launchMatch(modeId, takePlayers(modeId, math.min(readyCount, mode.maxPlayers)))
				else
					fillTimers[modeId] = nil
					broadcastQueue(modeId)
				end
			end)
		end
		broadcastQueue(modeId)
		return
	end

	launchMatch(modeId, takePlayers(modeId, count))
end

local function tryStartAll()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	if modeId == "auto" then
		modeId = MatchModes.resolveAuto(#Players:GetPlayers())
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId

	Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player), queueStatus(modeId))
	tryStartMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false }, queueStatus(modeId))
	broadcastQueue(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	task.defer(tryStartAll)
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId or "auto")
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerMode[player] then
			local modeId = playerMode[player]
			removeFromQueue(player)
			broadcastQueue(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.UPDATE_INTERVAL)
			if MatchStateService.isArenaBusy() then
				broadcastAllQueues()
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
