local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local ffaTimerStart = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function buildPayload(modeId, player)
	local mode = MatchModes.get(modeId)
	if not mode then
		return { status = "left" }
	end

	local queue = getQueue(modeId)
	local position = 0
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			position = index
			break
		end
	end

	local fillRemaining = nil
	if modeId == "ffa" and ffaTimerStart and #queue >= mode.minPlayers then
		fillRemaining = math.max(0, MatchmakingConfig.FFA_FILL_TIMEOUT - (os.clock() - ffaTimerStart))
	end

	return {
		status = "queued",
		modeId = modeId,
		modeLabel = mode.label,
		count = #queue,
		target = mode.targetPlayers,
		minPlayers = mode.minPlayers,
		position = position,
		pending = MatchStateService.isArenaBusy(),
		fillRemaining = fillRemaining,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildPayload(modeId, player))
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		ffaTimerStart = nil
	end

	broadcastQueue(modeId)
end

local function canStart(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = #queue

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.targetPlayers then
		return true
	end
	if modeId == "ffa" and ffaTimerStart then
		return os.clock() - ffaTimerStart >= MatchmakingConfig.FFA_FILL_TIMEOUT
	end
	return false
end

local function popPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local take = math.min(#queue, mode.targetPlayers)
	local matched = {}

	for _ = 1, take do
		local player = table.remove(queue, 1)
		if player then
			playerQueue[player] = nil
			table.insert(matched, player)
		end
	end

	if modeId == "ffa" then
		ffaTimerStart = nil
	end

	return matched
end

local function startMatch(modeId)
	if not canStart(modeId) or MatchStateService.isArenaBusy() then
		return
	end

	local matched = popPlayers(modeId)
	if #matched == 0 then
		return
	end

	broadcastQueue(modeId)

	for _, player in matched do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				status = "starting",
				modeId = modeId,
				modeLabel = MatchModes.get(modeId).label,
			})
		end
	end

	task.delay(MatchmakingConfig.START_DELAY, function()
		local active = {}
		for _, player in matched do
			if player.Parent then
				table.insert(active, player)
			end
		end
		if #active > 0 then
			MatchReady:Fire(active, modeId)
		end
	end)
end

local function joinQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not player.Parent then
		return
	end

	if playerQueue[player] == modeId then
		Remotes.QueueUpdate:FireClient(player, buildPayload(modeId, player))
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	if modeId == "ffa" and #getQueue(modeId) >= mode.minPlayers and not ffaTimerStart then
		ffaTimerStart = os.clock()
	end

	broadcastQueue(modeId)
	startMatch(modeId)
end

function MatchmakingService.getRecommendedModeId()
	return MatchModes.getRecommended(#Players:GetPlayers()).id
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId or MatchmakingService.getRecommendedModeId())
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.start()
	MatchStateService.onArenaFree(function()
		for modeId in queues do
			startMatch(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK)
			if getQueue("ffa") and #getQueue("ffa") >= MatchModes.ffa.minPlayers and ffaTimerStart then
				broadcastQueue("ffa")
				startMatch("ffa")
			end
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) == "string" and modeId ~= "" then
			MatchmakingService.joinQueue(player, modeId)
		else
			MatchmakingService.joinQueue(player, nil)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
