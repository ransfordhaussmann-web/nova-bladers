local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {}
local playerQueue = {}
local fillTimers = {}
local started = false
local canJoinQueue = function(_player)
	return true
end
local resolveDefaultMode = function(_player)
	return "training"
end

local function initQueues()
	for _, modeId in MatchModes.all() do
		queues[modeId] = {}
	end
end

local function getPlayerName(player)
	return player.DisplayName or player.Name
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local roster = queues[modeId]
	local names = {}
	for _, queuedPlayer in roster do
		if queuedPlayer.Parent then
			table.insert(names, getPlayerName(queuedPlayer))
		end
	end

	local status = "waiting"
	if GameMatchState.isBusy() then
		status = "pending"
	elseif #roster >= mode.maxPlayers then
		status = "starting"
	elseif mode.useFillTimeout and #roster >= mode.minPlayers and fillTimers[modeId] then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		count = #roster,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		names = names,
		status = status,
		inQueue = playerQueue[player] == modeId,
		arenaBusy = GameMatchState.isBusy(),
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, player in Players:GetPlayers() do
		local personal = buildQueuePayload(modeId, player)
		Remotes.QueueUpdate:FireClient(player, personal)
	end
end

local function broadcastAllQueues()
	for _, modeId in MatchModes.all() do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	local token = fillTimers[modeId]
	fillTimers[modeId] = nil
	return token
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local roster = queues[modeId]
	for i, queuedPlayer in roster do
		if queuedPlayer == player then
			table.remove(roster, i)
			break
		end
	end

	if #roster < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)
	return modeId
end

local function pruneQueue(modeId)
	local roster = queues[modeId]
	local cleaned = {}
	for _, queuedPlayer in roster do
		if queuedPlayer.Parent and playerQueue[queuedPlayer] == modeId then
			table.insert(cleaned, queuedPlayer)
		elseif playerQueue[queuedPlayer] == modeId then
			playerQueue[queuedPlayer] = nil
		end
	end
	queues[modeId] = cleaned
	return cleaned
end

local function takePlayers(modeId, count)
	local roster = pruneQueue(modeId)
	local taken = {}
	for i = 1, math.min(count, #roster) do
		local player = roster[i]
		table.insert(taken, player)
		playerQueue[player] = nil
	end

	local remaining = {}
	for i = #taken + 1, #roster do
		table.insert(remaining, roster[i])
	end
	queues[modeId] = remaining
	clearFillTimer(modeId)
	broadcastQueue(modeId)
	return taken
end

local function tryStartMode(modeId)
	if GameMatchState.isBusy() then
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	local roster = pruneQueue(modeId)
	local count = #roster

	if count < mode.minPlayers then
		return
	end

	if count >= mode.maxPlayers then
		local players = takePlayers(modeId, mode.maxPlayers)
		if #players > 0 then
			Bindables.MatchReady:Fire({ modeId = modeId, players = players })
		end
		return
	end

	if mode.useFillTimeout then
		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = token
			broadcastQueue(modeId)
			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if fillTimers[modeId] ~= token or GameMatchState.isBusy() then
					return
				end
				fillTimers[modeId] = nil
				local readyRoster = pruneQueue(modeId)
				if #readyRoster >= mode.minPlayers then
					local players = takePlayers(modeId, #readyRoster)
					if #players >= mode.minPlayers then
						Bindables.MatchReady:Fire({ modeId = modeId, players = players })
					end
				end
			end)
		end
		return
	end

	local players = takePlayers(modeId, mode.maxPlayers)
	if #players >= mode.minPlayers then
		Bindables.MatchReady:Fire({ modeId = modeId, players = players })
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not canJoinQueue(player) then
		return false, "not_in_hub"
	end
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] == modeId then
		return true
	end

	removeFromQueue(player)

	local mode = MatchModes.get(modeId)
	local roster = pruneQueue(modeId)
	if #roster >= mode.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId then
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			inQueue = false,
			status = "left",
		})
	end
	return modeId ~= nil
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.registerDefaultMode(fn)
	resolveDefaultMode = fn
end

function MatchmakingService.registerCanJoin(fn)
	canJoinQueue = fn
end

function MatchmakingService.onArenaFree()
	for _, modeId in MatchModes.all() do
		tryStartMode(modeId)
	end
	broadcastAllQueues()
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true
	initQueues()

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = resolveDefaultMode(player)
		end
		local ok, reason = MatchmakingService.joinQueue(player, modeId)
		if not ok then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				inQueue = false,
				status = "error",
				reason = reason,
			})
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
