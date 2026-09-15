local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillToken = 0
local started = false

local function queueList(modeId)
	return queues[modeId]
end

local function isValidMode(modeId)
	return MatchModes.get(modeId) ~= nil
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local list = queues[modeId]
	for i, p in list do
		if p == player then
			table.remove(list, i)
			break
		end
	end
	playerMode[player] = nil
end

local function playerNames(list)
	local names = {}
	for _, p in list do
		if p.Parent then
			table.insert(names, p.DisplayName)
		end
	end
	return names
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	local pending = MatchStateService.isBusy()

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = pending,
		playerNames = playerNames(list),
	}
end

local function sendQueueUpdate(player)
	if Remotes and Remotes.QueueUpdate then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueues()
	for _, player in Players:GetPlayers() do
		if playerMode[player] then
			sendQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local list = queues[modeId]
	local picked = {}
	local i = 1
	while i <= #list and #picked < count do
		local p = list[i]
		if p.Parent and HubService.getPhase(p) == "hub" then
			table.insert(picked, p)
			table.remove(list, i)
			playerMode[p] = nil
		else
			table.remove(list, i)
			playerMode[p] = nil
		end
	end
	return picked
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function tryLaunchMatch(modeId)
	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local list = queues[modeId]
	if #list < mode.minPlayers then
		return
	end

	if modeId == "ffa" and #list < mode.maxPlayers then
		return
	end

	local count = math.min(#list, mode.maxPlayers)
	local players = popPlayers(modeId, count)
	if #players < mode.minPlayers then
		for _, p in players do
			MatchmakingService.joinQueue(p, modeId)
		end
		return
	end

	cancelFfaFillTimer()
	MatchStateService.setBusy(true)

	for _, p in players do
		sendQueueUpdate(p)
	end
	broadcastAllQueues()

	MatchReady:Fire(players, modeId)
end

local function scheduleFfaFill()
	local mode = MatchModes.ffa
	if #queues.ffa < mode.minPlayers or #queues.ffa >= mode.maxPlayers then
		return
	end
	if MatchStateService.isBusy() then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT

	task.delay(timeout, function()
		if token ~= ffaFillToken then
			return
		end
		if MatchStateService.isBusy() then
			return
		end
		if #queues.ffa >= mode.minPlayers then
			tryLaunchMatch("ffa")
		end
	end)
end

local function onQueueChanged(modeId)
	broadcastAllQueues()

	if MatchStateService.isBusy() then
		return
	end

	local mode = MatchModes.get(modeId)
	local list = queues[modeId]

	if modeId == "ffa" then
		if #list >= mode.maxPlayers then
			tryLaunchMatch("ffa")
		elseif #list >= mode.minPlayers then
			scheduleFfaFill()
		else
			cancelFfaFillTimer()
		end
		return
	end

	if #list >= mode.maxPlayers then
		tryLaunchMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return false
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end
	if playerMode[player] == modeId then
		sendQueueUpdate(player)
		return true
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	sendQueueUpdate(player)
	onQueueChanged(modeId)

	if not MatchStateService.isBusy() and modeId ~= "ffa" then
		tryLaunchMatch(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)

	if modeId == "ffa" and #queues.ffa < MatchModes.ffa.minPlayers then
		cancelFfaFillTimer()
	end

	sendQueueUpdate(player)
	broadcastAllQueues()
end

function MatchmakingService.onArenaFreed()
	cancelFfaFillTimer()
	broadcastAllQueues()

	for _, modeId in { "training", "pvp", "ffa" } do
		local mode = MatchModes.get(modeId)
		if #queues[modeId] >= mode.minPlayers then
			if modeId == "ffa" then
				if #queues[modeId] >= mode.maxPlayers then
					tryLaunchMatch("ffa")
				else
					scheduleFfaFill()
				end
			else
				tryLaunchMatch(modeId)
			end
		end
	end
end

function MatchmakingService.getRecommendedMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, _ = RemotesSetup.ensure()
	local _, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedMode()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastAllQueues()
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
