local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes
local MatchReady
local MatchEnded

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillDeadline = nil
local onMatchStart

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
	end
end

local function buildQueuePayload(player, modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local status = "waiting"

	if MatchStateService.isArenaBusy() then
		status = "arena_busy"
	elseif #queue >= mode.minPlayers then
		status = "ready"
	end

	local secondsLeft
	if modeId == "ffa" and ffaFillDeadline and #queue >= mode.minPlayers then
		secondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = getQueue(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueueUpdate(modeId)
	end
end

local function clearQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(picked, player)
			playerQueue[player] = nil
		end
	end
	return picked
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	ffaFillDeadline = nil

	for _, player in playerList do
		clearQueueUpdate(player)
	end

	broadcastAllQueues()

	if onMatchStart then
		onMatchStart(playerList, modeId)
	end

	MatchReady:Fire({
		players = playerList,
		mode = modeId,
	})
end

local function tryStartTraining()
	if MatchStateService.isArenaBusy() then
		return
	end

	local queue = getQueue("training")
	if #queue >= 1 then
		launchMatch("training", popPlayers("training", 1))
	end
end

local function tryStartPvP()
	if MatchStateService.isArenaBusy() then
		return
	end

	local queue = getQueue("pvp")
	if #queue >= 2 then
		launchMatch("pvp", popPlayers("pvp", 2))
	end
end

local function tryStartFFA()
	if MatchStateService.isArenaBusy() then
		return
	end

	local mode = MatchModes.ffa
	local queue = getQueue("ffa")
	if #queue < mode.minPlayers then
		ffaFillDeadline = nil
		return
	end

	if not ffaFillDeadline then
		ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
	end

	local deadlineReached = os.clock() >= ffaFillDeadline
	local full = #queue >= mode.maxPlayers
	if deadlineReached or full then
		launchMatch("ffa", popPlayers("ffa", math.min(#queue, mode.maxPlayers)))
	end
end

local function tryStartMatches()
	tryStartTraining()
	tryStartPvP()
	tryStartFFA()
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if playerQueue[player] == modeId then
		broadcastQueueUpdate(modeId)
		return
	end

	removeFromQueue(player)

	local queue = getQueue(modeId)
	local mode = MatchModes.get(modeId)
	if #queue >= mode.maxPlayers then
		clearQueueUpdate(player)
		return
	end

	table.insert(queue, player)
	playerQueue[player] = modeId

	broadcastQueueUpdate(modeId)
	tryStartMatches()
end

local function leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	clearQueueUpdate(player)
	broadcastQueueUpdate(modeId)
end

local function resolveQuickMatchMode()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init(options)
	Remotes = options.remotes or RemotesSetup.ensure()
	local _, bindables = RemotesSetup.ensure()
	MatchReady = bindables.MatchReady
	MatchEnded = bindables.MatchEnded
	onMatchStart = options.onMatchStart

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" or modeId == "" then
			modeId = resolveQuickMatchMode()
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchStateService.setArenaBusy(false)
		task.defer(tryStartMatches)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removeFromQueue(player)
			broadcastQueueUpdate(modeId)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			if not MatchStateService.isArenaBusy() then
				tryStartMatches()
			end
			for modeId in queues do
				if #getQueue(modeId) > 0 then
					broadcastQueueUpdate(modeId)
				end
			end
		end
	end)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or modeId == "" then
		modeId = resolveQuickMatchMode()
	end
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

return MatchmakingService
