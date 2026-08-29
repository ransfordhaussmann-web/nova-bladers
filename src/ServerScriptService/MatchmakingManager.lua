--[[
	MatchmakingManager — queue players before arena matches start.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BeyConfig = require(ReplicatedStorage.NovaBladers.BeyConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingManager = {}

local queue = {}
local queueIndex = {}
local firstJoinAt = nil
local countdownToken = 0
local countdownRemaining = nil

local function predictMode(count)
	local cfg = BeyConfig.MATCHMAKING
	if count >= cfg.FFA_THRESHOLD then
		return "ffa", "Modus: FFA"
	elseif count >= cfg.PVP_THRESHOLD then
		return "pvp", "Modus: 1v1 PvP"
	end
	return "training", "Modus: Training"
end

local function buildPayload(player)
	local size = #queue
	local mode, modeLabel = predictMode(size)
	return {
		inQueue = true,
		position = queueIndex[player],
		queueSize = size,
		mode = mode,
		modeLabel = modeLabel,
		status = countdownRemaining and "starting" or "waiting",
		countdown = countdownRemaining,
		minPlayers = BeyConfig.MATCHMAKING.PVP_THRESHOLD,
	}
end

local function broadcastQueue()
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildPayload(queuedPlayer))
		end
	end
end

local function cancelCountdown()
	countdownToken += 1
	countdownRemaining = nil
end

local function removePlayer(player)
	local idx = queueIndex[player]
	if not idx then
		return
	end

	table.remove(queue, idx)
	queueIndex[player] = nil
	for i, queuedPlayer in ipairs(queue) do
		queueIndex[queuedPlayer] = i
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end

	if #queue == 0 then
		firstJoinAt = nil
		cancelCountdown()
	else
		broadcastQueue()
	end
end

local function popQueueForMatch()
	cancelCountdown()
	local players = table.clone(queue)
	table.clear(queue)
	table.clear(queueIndex)
	firstJoinAt = nil

	for _, queuedPlayer in players do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, { inQueue = false, status = "matched" })
		end
	end

	return players
end

local function fireMatchReady(players)
	local bindable = Bindables:FindFirstChild("MatchReady")
	if bindable then
		bindable:Fire(players)
	end
end

local function startCountdown(seconds)
	countdownToken += 1
	local token = countdownToken

	task.spawn(function()
		for i = seconds, 1, -1 do
			if token ~= countdownToken then
				return
			end
			countdownRemaining = i
			broadcastQueue()
			task.wait(1)
		end

		if token ~= countdownToken or #queue == 0 then
			return
		end

		countdownRemaining = nil
		local players = popQueueForMatch()
		if #players > 0 then
			fireMatchReady(players)
		end
	end)
end

local function shouldStartCountdown()
	local size = #queue
	local cfg = BeyConfig.MATCHMAKING

	if size >= cfg.FFA_THRESHOLD then
		return true, cfg.COUNTDOWN_SECONDS
	end
	if size >= cfg.PVP_THRESHOLD then
		return true, cfg.COUNTDOWN_SECONDS
	end
	if size >= 1 and firstJoinAt and (os.clock() - firstJoinAt) >= cfg.SOLO_TIMEOUT then
		return true, cfg.SOLO_COUNTDOWN_SECONDS
	end
	return false, 0
end

local function evaluateQueue()
	if countdownRemaining or #queue == 0 then
		return
	end

	local shouldStart, seconds = shouldStartCountdown()
	if shouldStart then
		startCountdown(seconds)
	end
end

function MatchmakingManager.join(player)
	if queueIndex[player] or not player.Parent then
		return
	end

	table.insert(queue, player)
	queueIndex[player] = #queue
	if #queue == 1 then
		firstJoinAt = os.clock()
	end

	broadcastQueue()
	evaluateQueue()
end

function MatchmakingManager.leave(player)
	removePlayer(player)
end

function MatchmakingManager.isQueued(player)
	return queueIndex[player] ~= nil
end

function MatchmakingManager.init()
	task.spawn(function()
		while true do
			task.wait(BeyConfig.MATCHMAKING.EVAL_INTERVAL)
			evaluateQueue()
		end
	end)

	Players.PlayerRemoving:Connect(removePlayer)
end

return MatchmakingManager
