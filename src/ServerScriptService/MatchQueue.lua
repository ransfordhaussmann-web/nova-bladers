--[[
	MatchQueue — gathers arena players and starts matches when ready.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchQueueConfig = require(ReplicatedStorage.NovaBladers.MatchQueueConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchQueue = {}

local queued = {}
local queuedSet = {}
local gatherToken = 0
local soloToken = 0
local onMatchReady = nil

local function getModeForCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel(mode)
	return MatchQueueConfig.MODE_LABELS[mode] or mode
end

local function buildSnapshot()
	local count = #queued
	local mode = getModeForCount(count)
	local names = {}
	for _, player in queued do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end

	return {
		count = count,
		mode = mode,
		modeLabel = getModeLabel(mode),
		target = MatchQueueConfig.MODE_TARGETS[mode],
		players = names,
	}
end

local function broadcast()
	local snapshot = buildSnapshot()
	for _, player in queued do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, snapshot)
		end
	end
end

local function cancelTimers()
	gatherToken += 1
	soloToken += 1
end

function MatchQueue.setOnMatchReady(callback)
	onMatchReady = callback
end

function MatchQueue.isQueued(player)
	return queuedSet[player] == true
end

function MatchQueue.getQueuedPlayers()
	local copy = {}
	for _, player in queued do
		table.insert(copy, player)
	end
	return copy
end

function MatchQueue.popMatch()
	if #queued == 0 then
		return
	end

	local players = {}
	for _, player in queued do
		if player.Parent then
			table.insert(players, player)
		end
	end

	queued = {}
	queuedSet = {}
	cancelTimers()

	if #players > 0 and onMatchReady then
		onMatchReady(players)
	end
end

local function scheduleGather()
	gatherToken += 1
	local token = gatherToken
	task.delay(MatchQueueConfig.GATHER_DELAY, function()
		if token ~= gatherToken then
			return
		end
		if #queued >= 2 then
			MatchQueue.popMatch()
		end
	end)
end

local function scheduleSolo()
	soloToken += 1
	local token = soloToken
	task.delay(MatchQueueConfig.SOLO_WAIT, function()
		if token ~= soloToken then
			return
		end
		if #queued == 1 then
			MatchQueue.popMatch()
		end
	end)
end

local function scheduleFfaPop()
	gatherToken += 1
	soloToken += 1
	local token = gatherToken
	task.delay(MatchQueueConfig.FFA_POP_DELAY, function()
		if token ~= gatherToken then
			return
		end
		if #queued >= 3 then
			MatchQueue.popMatch()
		end
	end)
end

function MatchQueue.join(player)
	if not player or not player.Parent then
		return false
	end
	if queuedSet[player] then
		broadcast()
		return true
	end

	table.insert(queued, player)
	queuedSet[player] = true
	broadcast()

	local count = #queued
	if count == 1 then
		scheduleSolo()
	elseif count == 2 then
		cancelTimers()
		scheduleGather()
	elseif count >= 3 then
		scheduleFfaPop()
	end

	return true
end

function MatchQueue.leave(player)
	if not queuedSet[player] then
		return false
	end

	queuedSet[player] = nil
	for i = #queued, 1, -1 do
		if queued[i] == player then
			table.remove(queued, i)
		end
	end

	cancelTimers()
	broadcast()

	if #queued == 1 then
		scheduleSolo()
	elseif #queued == 2 then
		scheduleGather()
	elseif #queued >= 3 then
		scheduleFfaPop()
	end

	return true
end

function MatchQueue.removePlayer(player)
	MatchQueue.leave(player)
end

return MatchQueue
