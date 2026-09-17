--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

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

local playerEntry = {}
local fillTokens = {}
local callbacks = {}

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function isPlayerQueued(player)
	local entry = playerEntry[player]
	return entry ~= nil
end

local function buildUpdatePayload(player, entry)
	local mode = MatchModes.get(entry.modeId)
	local queueList = queues[entry.modeId] or {}
	local position = 0
	for i, queuedPlayer in queueList do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		status = entry.status,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		position = position,
		queueSize = #queueList,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		fillSecondsLeft = entry.fillSecondsLeft,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function sendQueueUpdate(player)
	local entry = playerEntry[player]
	if not entry or not player.Parent then
		return
	end
	QueueUpdate:FireClient(player, buildUpdatePayload(player, entry))
end

local function broadcastQueueUpdates(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer)
	end
end

local function setEntryStatus(player, status)
	local entry = playerEntry[player]
	if entry then
		entry.status = status
		sendQueueUpdate(player)
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
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

	playerEntry[player] = nil

	if callbacks.onLeaveQueue then
		callbacks.onLeaveQueue(player)
	end

	broadcastQueueUpdates(modeId)
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerEntry[player] = nil
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setArenaBusy(true)

	for _, player in playerList do
		if callbacks.onMatchLaunch then
			callbacks.onMatchLaunch(player)
		end
	end

	MatchReady:Fire(modeId, playerList)
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		for _, player in queue do
			setEntryStatus(player, "waiting")
		end
		return
	end

	if MatchStateService.isArenaBusy() then
		for _, player in queue do
			setEntryStatus(player, "pending")
			if callbacks.onPendingQueue then
				callbacks.onPendingQueue(player)
			end
		end
		return
	end

	if modeId == "ffa" and fillTokens[modeId] then
		return
	end

	if mode.fillTimeout > 0 and #queue >= mode.minPlayers and #queue < mode.maxPlayers then
		if not fillTokens[modeId] then
			fillTokens[modeId] = 0
		end
		fillTokens[modeId] += 1
		local token = fillTokens[modeId]

		for _, player in queue do
			local entry = playerEntry[player]
			if entry then
				entry.status = "filling"
				entry.fillSecondsLeft = mode.fillTimeout
			end
		end
		broadcastQueueUpdates(modeId)

		task.spawn(function()
			local remaining = mode.fillTimeout
			while remaining > 0 do
				task.wait(1)
				remaining -= 1

				if fillTokens[modeId] ~= token then
					return
				end

				local currentQueue = queues[modeId]
				if #currentQueue < mode.minPlayers then
					fillTokens[modeId] = nil
					tryStartMode(modeId)
					return
				end

				for _, player in currentQueue do
					local entry = playerEntry[player]
					if entry and entry.status == "filling" then
						entry.fillSecondsLeft = remaining
					end
				end
				broadcastQueueUpdates(modeId)

				if #currentQueue >= mode.maxPlayers then
					break
				end
			end

			if fillTokens[modeId] ~= token then
				return
			end
			fillTokens[modeId] = nil

			if MatchStateService.isArenaBusy() then
				for _, player in queues[modeId] do
					setEntryStatus(player, "pending")
					if callbacks.onPendingQueue then
						callbacks.onPendingQueue(player)
					end
				end
				return
			end

			local count = math.min(#queues[modeId], mode.maxPlayers)
			local players = popPlayers(modeId, count)
			launchMatch(modeId, players)
			broadcastQueueUpdates(modeId)
		end)
		return
	end

	local count = mode.maxPlayers
	if modeId == "training" then
		count = 1
	elseif modeId == "pvp" then
		count = MatchmakingConfig.PVP_PLAYERS
	else
		count = math.min(#queue, mode.maxPlayers)
	end

	if #queue < count then
		for _, player in queue do
			setEntryStatus(player, "waiting")
		end
		return
	end

	local players = popPlayers(modeId, count)
	launchMatch(modeId, players)
	broadcastQueueUpdates(modeId)
end

local function tryAllQueues()
	for modeId in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "unknown_mode"
	end

	if callbacks.canJoinQueue and not callbacks.canJoinQueue(player) then
		return false, "not_in_hub"
	end

	if isPlayerQueued(player) then
		removeFromQueue(player)
	end

	fillTokens[modeId] = nil

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = "waiting",
		fillSecondsLeft = nil,
	}

	if callbacks.onJoinQueue then
		callbacks.onJoinQueue(player, modeId)
	end

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if not isPlayerQueued(player) then
		return false
	end

	local modeId = playerEntry[player].modeId
	fillTokens[modeId] = nil
	removeFromQueue(player)
	tryStartMode(modeId)
	return true
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

function MatchmakingService.isQueued(player)
	return isPlayerQueued(player)
end

function MatchmakingService.getQueueSize(modeId)
	return getQueueSize(modeId)
end

function MatchmakingService.register(newCallbacks)
	callbacks = newCallbacks or {}
end

function MatchmakingService.start()
	MatchStateService.onArenaFreed(function()
		tryAllQueues()
	end)

	QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if isPlayerQueued(player) then
			MatchmakingService.leaveQueue(player)
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
