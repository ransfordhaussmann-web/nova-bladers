local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillDeadline = nil
local tickRunning = false

local function queueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and queueSize("ffa") < MatchModes.FFA.minPlayers then
		ffaFillDeadline = nil
	end
end

local function buildQueuePayload(player)
	local modeId = playerMode[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queued in queue do
		if queued == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isArenaBusy() then
		status = "pending"
	elseif modeId == "ffa" and #queue >= mode.minPlayers and ffaFillDeadline then
		status = "filling"
	end

	local secondsLeft = nil
	if status == "filling" and ffaFillDeadline then
		secondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		secondsLeft = secondsLeft,
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueues()
	for player in playerMode do
		if player.Parent then
			broadcastQueueUpdate(player)
		end
	end
end

local function popPlayers(modeId, count)
	local queue = queues[modeId]
	local picked = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function launchMatch(players, modeId)
	if #players == 0 then
		return
	end

	for _, player in players do
		HubService.leaveHubForArena(player)
		broadcastQueueUpdate(player)
	end

	MatchReady:Fire(players, modeId)
end

local function tryStartTraining()
	local mode = MatchModes.Training
	if queueSize(mode.id) < mode.minPlayers then
		return
	end
	launchMatch(popPlayers(mode.id, mode.maxPlayers), mode.id)
end

local function tryStartPvP()
	local mode = MatchModes.PvP
	if queueSize(mode.id) < mode.minPlayers then
		return
	end
	launchMatch(popPlayers(mode.id, mode.maxPlayers), mode.id)
end

local function tryStartFFA()
	local mode = MatchModes.FFA
	local size = queueSize(mode.id)
	if size < mode.minPlayers then
		ffaFillDeadline = nil
		return
	end

	if size >= mode.maxPlayers then
		ffaFillDeadline = nil
		launchMatch(popPlayers(mode.id, mode.maxPlayers), mode.id)
		return
	end

	if not ffaFillDeadline then
		ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		broadcastAllQueues()
		return
	end

	if os.clock() >= ffaFillDeadline then
		ffaFillDeadline = nil
		launchMatch(popPlayers(mode.id, size), mode.id)
	end
end

local function tryStartMatches()
	if MatchStateService.isArenaBusy() then
		broadcastAllQueues()
		return
	end

	tryStartTraining()
	if MatchStateService.isArenaBusy() then
		return
	end

	tryStartPvP()
	if MatchStateService.isArenaBusy() then
		return
	end

	tryStartFFA()
end

local function joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	broadcastQueueUpdate(player)
	tryStartMatches()
end

local function leaveQueue(player)
	if not playerMode[player] then
		return
	end
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		tryStartMatches()
	end)

	if not tickRunning then
		tickRunning = true
		task.spawn(function()
			while true do
				task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
				if ffaFillDeadline and not MatchStateService.isArenaBusy() then
					tryStartFFA()
				end
			end
		end)
	end

	print("[MatchmakingService] Queue system ready")
end

function MatchmakingService.joinQueue(player, modeId)
	joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

return MatchmakingService
