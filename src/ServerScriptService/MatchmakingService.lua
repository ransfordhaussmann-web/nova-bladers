local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local Remotes, Bindables = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillDeadline = nil
local pendingMatch = nil
local initialized = false

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromAllQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerQueue[player] = nil

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
	end
end

local function buildQueuePayload(modeId, player)
	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)
	local pending = pendingMatch ~= nil and pendingMatch.modeId == modeId

	return {
		modeId = modeId,
		label = mode.label,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		inQueue = playerQueue[player] == modeId,
		pending = pending,
		arenaBusy = MatchStateService.isBusy(),
		fillSecondsLeft = nil,
	}
end

local function sendQueueUpdate(player, modeId)
	if not player.Parent then
		return
	end
	local payload = buildQueuePayload(modeId, player)
	if modeId == "ffa" and ffaFillDeadline and playerQueue[player] == "ffa" then
		payload.fillSecondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end
	Remotes.QueueUpdate:FireClient(player, payload)
end

local function broadcastQueue(modeId)
	for _, player in Players:GetPlayers() do
		if playerQueue[player] == modeId or HubService.getPhase(player) == "hub" then
			sendQueueUpdate(player, modeId)
		end
	end
end

local function launchMatch(modeId, matchedPlayers)
	pendingMatch = nil
	ffaFillDeadline = nil

	for _, player in matchedPlayers do
		removeFromAllQueues(player)
		HubService.leaveHubForArena(player)
	end

	MatchStateService.setBusy(true)
	Bindables.MatchReady:Fire({
		mode = modeId,
		players = matchedPlayers,
	})

	for modeKey in queues do
		broadcastQueue(modeKey)
	end
end

local function tryStartMatch(modeId)
	if not MatchStateService.canStartMatch() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if #queue < mode.maxPlayers and ffaFillDeadline and os.clock() < ffaFillDeadline then
			return false
		end
	end

	local matched = {}
	for i = 1, math.min(#queue, mode.maxPlayers) do
		table.insert(matched, queue[i])
	end

	if #matched < mode.minPlayers then
		return false
	end

	launchMatch(modeId, matched)
	return true
end

local function processQueues()
	if pendingMatch then
		if MatchStateService.canStartMatch() then
			launchMatch(pendingMatch.modeId, pendingMatch.players)
		end
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local queue = getQueue(modeId)
		local mode = MatchModes.get(modeId)

		if #queue >= mode.minPlayers and not MatchStateService.canStartMatch() then
			local matched = {}
			for i = 1, math.min(#queue, mode.maxPlayers) do
				table.insert(matched, queue[i])
			end
			if #matched >= mode.minPlayers then
				pendingMatch = { modeId = modeId, players = matched }
				for _, player in matched do
					sendQueueUpdate(player, modeId)
				end
				return
			end
		end

		if modeId == "ffa" and #queue >= mode.minPlayers and not ffaFillDeadline then
			ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		end

		if tryStartMatch(modeId) then
			return
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if playerQueue[player] == modeId then
		sendQueueUpdate(player, modeId)
		return
	end

	removeFromAllQueues(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		sendQueueUpdate(player, modeId)
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	if modeId == "ffa" and #queue >= mode.minPlayers and not ffaFillDeadline then
		ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	sendQueueUpdate(player, modeId)
	broadcastQueue(modeId)
	processQueues()
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromAllQueues(player)
	broadcastQueue(modeId)
	processQueues()
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	pendingMatch = nil
	processQueues()
end

function MatchmakingService.init()
	if initialized then
		return
	end
	initialized = true

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
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
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			processQueues()
		end
	end)
end

return MatchmakingService
