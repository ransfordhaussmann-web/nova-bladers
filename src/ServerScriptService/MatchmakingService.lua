--[[
	MatchmakingService — per-mode queues that group players before a match starts.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local canStartMatch = function()
	return true
end
local onQueueChanged

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function buildQueuePayload(player)
	local entry = playerQueue[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchmakingConfig.getMode(entry.modeId)
	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		waiting = getQueueSize(entry.modeId),
		needed = mode.minPlayers,
	}
end

local function sendQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastQueueMode(modeId)
	for _, queuedPlayer in queues[modeId] do
		sendQueueUpdate(queuedPlayer)
	end
end

function MatchmakingService.setCanStart(fn)
	canStartMatch = fn
end

function MatchmakingService.setOnQueueChanged(fn)
	onQueueChanged = fn
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.getQueuedMode(player)
	local entry = playerQueue[player]
	return entry and entry.modeId
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return false
	end

	local modeId = entry.modeId
	playerQueue[player] = nil

	for i, queuedPlayer in queues[modeId] do
		if queuedPlayer == player then
			table.remove(queues[modeId], i)
			break
		end
	end

	sendQueueUpdate(player)
	broadcastQueueMode(modeId)

	if onQueueChanged then
		onQueueChanged(player, nil)
	end

	return true
end

local function takePlayers(modeId, count)
	local taken = {}
	for _ = 1, count do
		local nextPlayer = table.remove(queues[modeId], 1)
		if not nextPlayer then
			break
		end
		playerQueue[nextPlayer] = nil
		table.insert(taken, nextPlayer)
	end
	return taken
end

local function tryStartMode(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return
	end

	while #queues[modeId] >= mode.minPlayers and canStartMatch() do
		local matched = takePlayers(modeId, mode.minPlayers)
		if #matched < mode.minPlayers then
			break
		end

		for _, queuedPlayer in queues[modeId] do
			sendQueueUpdate(queuedPlayer)
		end

		Bindables.MatchReady:Fire({
			modeId = modeId,
			players = matched,
		})
	end
end

function MatchmakingService.tryStartMatches()
	for modeId in MatchmakingConfig.MODES do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.isValidMode(modeId) then
		return false, "invalid_mode"
	end

	if playerQueue[player] and playerQueue[player].modeId == modeId then
		sendQueueUpdate(player)
		return true
	end

	MatchmakingService.leaveQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = { modeId = modeId }

	sendQueueUpdate(player)
	broadcastQueueMode(modeId)

	if onQueueChanged then
		onQueueChanged(player, modeId)
	end

	tryStartMode(modeId)
	return true
end

Remotes.JoinMatchQueue.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.LeaveMatchQueue.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

return MatchmakingService
