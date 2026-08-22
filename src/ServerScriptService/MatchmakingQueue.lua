--[[
	MatchmakingQueue — gathers players at the arena portal before starting a match.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()
local QueueUpdate = Remotes.QueueUpdate

local MatchmakingQueue = {}

local queue = {}
local countdownActive = false
local countdownEnd = 0
local readyCallback = nil
local canStartMatch = nil

local GATHER_TIME = HubConfig.QUEUE_GATHER_SECONDS or 8

local function getModeId(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel(count)
	if count >= 3 then
		return "Modus: FFA"
	elseif count == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function buildPayload()
	local remaining = 0
	if countdownActive then
		remaining = math.max(0, math.ceil(countdownEnd - os.clock()))
	end
	return {
		players = #queue,
		mode = getModeId(#queue),
		modeLabel = getModeLabel(#queue),
		countdown = remaining,
		inQueue = #queue > 0,
	}
end

local function broadcast()
	local payload = buildPayload()
	for _, player in queue do
		if player.Parent then
			QueueUpdate:FireClient(player, payload)
		end
	end
end

local function flushQueue()
	local players = table.clone(queue)
	table.clear(queue)
	countdownActive = false
	return players
end

local function tryStartMatch()
	if #queue == 0 or not countdownActive then
		return
	end
	if canStartMatch and not canStartMatch() then
		countdownEnd = os.clock() + 3
		return
	end

	local players = flushQueue()
	broadcast()

	local valid = {}
	for _, player in players do
		if player.Parent then
			table.insert(valid, player)
		end
	end

	if #valid > 0 and readyCallback then
		readyCallback(valid)
	end
end

local function runCountdown()
	while countdownActive do
		broadcast()
		if os.clock() >= countdownEnd then
			tryStartMatch()
			return
		end
		task.wait(0.5)
	end
end

function MatchmakingQueue.onReady(callback)
	readyCallback = callback
end

function MatchmakingQueue.setCanStart(fn)
	canStartMatch = fn
end

function MatchmakingQueue.isQueued(player)
	return table.find(queue, player) ~= nil
end

function MatchmakingQueue.getQueue()
	return table.clone(queue)
end

function MatchmakingQueue.join(player)
	if not player or not player.Parent then
		return false
	end
	if table.find(queue, player) then
		return true
	end

	table.insert(queue, player)

	if not countdownActive then
		countdownActive = true
		countdownEnd = os.clock() + GATHER_TIME
		task.spawn(runCountdown)
	end

	broadcast()
	return true
end

function MatchmakingQueue.leave(player)
	local idx = table.find(queue, player)
	if not idx then
		return false
	end

	table.remove(queue, idx)

	if #queue == 0 then
		countdownActive = false
	end

	if player.Parent then
		QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcast()
	return true
end

function MatchmakingQueue.removePlayers(players)
	for _, player in players do
		MatchmakingQueue.leave(player)
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.leave(player)
end)

return MatchmakingQueue
