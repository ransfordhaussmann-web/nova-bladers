--[[
	MatchmakingQueue — collects arena-ready players and starts matches when ready.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local Remotes = RemotesSetup.ensure()

local MatchmakingQueue = {}

local CONFIG = {
	SOLO_TIMEOUT = 12,
	DUO_COUNTDOWN = 4,
	FFA_COUNTDOWN = 3,
	MAX_PLAYERS = 8,
}

local queue = {}
local queueSet = {}
local status = "idle"
local countdownEndsAt = 0
local countdownToken = 0
local soloToken = 0
local onMatchReady

local function getModeLabel(count)
	if count >= 3 then
		return "FFA"
	elseif count == 2 then
		return "1v1 PvP"
	end
	return "Training"
end

local function getQueueSnapshot()
	local players = {}
	for _, player in queue do
		if player.Parent then
			table.insert(players, player)
		end
	end
	return players
end

local function broadcastUpdate(extra)
	local snapshot = getQueueSnapshot()
	local count = #snapshot
	local payload = {
		status = status,
		count = count,
		modeLabel = getModeLabel(count),
		countdown = extra and extra.countdown,
	}

	for _, player in snapshot do
		if player.Parent then
			Remotes.MatchQueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearCountdown()
	countdownToken += 1
	countdownEndsAt = 0
end

local function clearSoloTimer()
	soloToken += 1
end

local function resetQueueState()
	queue = {}
	queueSet = {}
	status = "idle"
	clearCountdown()
	clearSoloTimer()
end

local function removePlayer(player)
	if not queueSet[player] then
		return
	end
	queueSet[player] = nil
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end
end

local function isInActiveMatch(player)
	if not onMatchReady then
		return false
	end
	return onMatchReady.isBusy and onMatchReady.isBusy(player)
end

function MatchmakingQueue.isQueued(player)
	return queueSet[player] == true
end

function MatchmakingQueue.leave(player)
	if not queueSet[player] then
		return
	end

	removePlayer(player)
	status = #queue > 0 and "waiting" or "idle"
	clearCountdown()
	clearSoloTimer()

	if player.Parent then
		Remotes.MatchQueueUpdate:FireClient(player, {
			status = "left",
			count = 0,
			modeLabel = "",
		})
	end

	broadcastUpdate()
	MatchmakingQueue.evaluate()
end

function MatchmakingQueue.join(player)
	if queueSet[player] or isInActiveMatch(player) then
		return false
	end

	table.insert(queue, player)
	queueSet[player] = true
	status = "waiting"
	broadcastUpdate()
	MatchmakingQueue.evaluate()
	return true
end

local function startMatchFromQueue()
	clearCountdown()
	clearSoloTimer()

	local snapshot = getQueueSnapshot()
	resetQueueState()

	if #snapshot == 0 or not onMatchReady then
		return
	end

	onMatchReady.start(snapshot)
end

local function runCountdown(seconds)
	clearCountdown()
	clearSoloTimer()
	status = "countdown"
	countdownToken += 1
	local token = countdownToken

	for remaining = seconds, 1, -1 do
		if token ~= countdownToken then
			return
		end
		broadcastUpdate({ countdown = remaining })
		task.wait(1)
	end

	if token ~= countdownToken then
		return
	end

	startMatchFromQueue()
end

function MatchmakingQueue.evaluate()
	local count = #getQueueSnapshot()
	if count == 0 then
		status = "idle"
		clearCountdown()
		clearSoloTimer()
		return
	end

	if count >= 3 then
		runCountdown(CONFIG.FFA_COUNTDOWN)
	elseif count == 2 then
		runCountdown(CONFIG.DUO_COUNTDOWN)
	elseif count == 1 then
		status = "waiting"
		clearCountdown()
		clearSoloTimer()
		soloToken += 1
		local token = soloToken
		task.delay(CONFIG.SOLO_TIMEOUT, function()
			if token ~= soloToken or not queueSet[queue[1]] then
				return
			end
			if #getQueueSnapshot() == 1 then
				runCountdown(2)
			end
		end)
	else
		status = "waiting"
	end

	broadcastUpdate()
end

function MatchmakingQueue.registerHandlers(handlers)
	onMatchReady = handlers
end

Players.PlayerRemoving:Connect(function(player)
	if queueSet[player] then
		MatchmakingQueue.leave(player)
	end
end)

return MatchmakingQueue
