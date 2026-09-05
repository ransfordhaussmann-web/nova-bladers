--[[
	Matchmaking queue — players wait at the hub portal until auto-start.
	Training: 6s (1 player) | 1v1 PvP: 12s (2) | FFA: 4s (3+)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local QUEUE_DELAYS = {
	training = 6,
	pvp = 12,
	ffa = 4,
}

local queue = {}
local queueSet = {}
local countdownToken = 0
local countdownEnd = 0
local hubCallbacks = {}
local isMatchIdle = function()
	return true
end

local MatchmakingService = {}

local function getModeFromCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel(mode)
	if mode == "ffa" then
		return "FFA"
	elseif mode == "pvp" then
		return "1v1 PvP"
	end
	return "Training"
end

local function getDelayForCount(count)
	return QUEUE_DELAYS[getModeFromCount(count)]
end

local function isInQueue(player)
	return queueSet[player] == true
end

local function buildPayload()
	local names = {}
	for _, player in queue do
		if player.Parent then
			table.insert(names, player.DisplayName)
		end
	end

	local count = #names
	local mode = getModeFromCount(count)
	local timeLeft = 0
	if countdownEnd > 0 then
		timeLeft = math.max(0, math.ceil(countdownEnd - os.clock()))
	end

	return {
		inQueue = count > 0,
		count = count,
		mode = mode,
		modeLabel = getModeLabel(mode),
		timeLeft = timeLeft,
		players = names,
	}
end

local function broadcastQueue()
	local payload = buildPayload()
	for _, player in queue do
		if player.Parent then
			Remotes.MatchmakingQueue:FireClient(player, payload)
		end
	end
end

local function stopTicker()
	tickerActive = false
end

local tickerActive = false

local function startTicker()
	if tickerActive then
		return
	end
	tickerActive = true
	task.spawn(function()
		while tickerActive and #queue > 0 do
			broadcastQueue()
			task.wait(1)
		end
		tickerActive = false
	end)
end

local function clearCountdown()
	countdownToken += 1
	countdownEnd = 0
end

local function canStartMatch()
	return isMatchIdle()
end

local scheduleCountdown

local function startQueuedMatch()
	if #queue == 0 then
		return
	end
	if not canStartMatch() then
		scheduleCountdown()
		return
	end

	local players = {}
	for _, player in queue do
		if player.Parent and HubService.getPhase(player) ~= "arena" then
			table.insert(players, player)
		end
	end

	if #players == 0 then
		MatchmakingService.clearQueue()
		return
	end

	MatchmakingService.clearQueue()

	for _, player in players do
		if hubCallbacks.onMatchStart then
			hubCallbacks.onMatchStart(player)
		end
	end

	Bindables.StartMatch:Fire(players)
end

scheduleCountdown = function()
	clearCountdown()
	if #queue == 0 then
		return
	end

	local token = countdownToken
	local delay = getDelayForCount(#queue)
	countdownEnd = os.clock() + delay

	task.delay(delay, function()
		if token ~= countdownToken or #queue == 0 then
			return
		end
		if not canStartMatch() then
			scheduleCountdown()
			return
		end
		startQueuedMatch()
	end)

	broadcastQueue()
	startTicker()
end

function MatchmakingService.registerHubCallbacks(callbacks)
	hubCallbacks = callbacks or {}
end

function MatchmakingService.registerIsIdle(checker)
	isMatchIdle = checker or function()
		return true
	end
end

function MatchmakingService.clearQueue()
	table.clear(queue)
	table.clear(queueSet)
	clearCountdown()
	stopTicker()
end

function MatchmakingService.joinQueue(player)
	if not player or not player.Parent then
		return false
	end
	if HubService.getPhase(player) == "arena" then
		return false
	end
	if isInQueue(player) then
		broadcastQueue()
		return true
	end

	table.insert(queue, player)
	queueSet[player] = true
	scheduleCountdown()
	return true
end

function MatchmakingService.leaveQueue(player)
	if not isInQueue(player) then
		return false
	end

	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
			break
		end
	end
	queueSet[player] = nil

	Remotes.MatchmakingQueue:FireClient(player, { inQueue = false })

	if #queue == 0 then
		clearCountdown()
		stopTicker()
	else
		scheduleCountdown()
	end

	return true
end

function MatchmakingService.removePlayer(player)
	if isInQueue(player) then
		MatchmakingService.leaveQueue(player)
	end
end

function MatchmakingService.onMatchEnded()
	if #queue > 0 then
		scheduleCountdown()
	end
end

Remotes.LeaveQueue.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.removePlayer(player)
end)

return MatchmakingService
