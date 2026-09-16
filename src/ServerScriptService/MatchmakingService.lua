--[[
	MatchmakingService — per-mode queues with FFA fill timeout and arena-pending state.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerMode = {}
local ffaFillDeadline = nil
local ffaFillToken = 0
local started = false

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function getMode(modeId)
	return MatchModes.get(modeId)
end

local function queueContains(modeId, player)
	for _, queued in queues[modeId] do
		if queued == player then
			return true
		end
	end
	return false
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for index, queued in queue do
		if queued == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and #queue < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end
end

local function buildQueuePayload(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	local status = "waiting"

	if MatchStateService.isArenaBusy() and #queue >= mode.minPlayers then
		status = "pending"
	elseif modeId == "ffa" and #queue >= mode.minPlayers and ffaFillDeadline then
		status = "filling"
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		queued = #queue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		status = status,
		fillSecondsLeft = ffaFillDeadline and math.max(0, math.ceil(ffaFillDeadline - os.clock())) or nil,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId)
	for _, player in queues[modeId] do
		if isValidPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, payload)
		end
	end
end

local function clearQueue(modeId)
	for _, player in queues[modeId] do
		playerMode[player] = nil
		if isValidPlayer(player) then
			Remotes.QueueUpdate:FireClient(player, { status = "idle" })
		end
	end
	queues[modeId] = {}
	if modeId == "ffa" then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end
end

local function popPlayers(modeId, count)
	local selected = {}
	local queue = queues[modeId]
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			table.insert(selected, player)
			playerMode[player] = nil
			Remotes.QueueUpdate:FireClient(player, { status = "starting" })
		end
	end
	return selected
end

local function tryStartMode(modeId)
	local mode = getMode(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueue(modeId)
		return
	end

	local count = math.min(#queue, mode.maxPlayers)
	if modeId == "ffa" and #queue < mode.maxPlayers then
		if not ffaFillDeadline then
			ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
			ffaFillToken += 1
			local token = ffaFillToken
			broadcastQueue(modeId)
			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				if token ~= ffaFillToken then
					return
				end
				ffaFillDeadline = nil
				tryStartMode("ffa")
			end)
			return
		end

		if os.clock() < ffaFillDeadline then
			broadcastQueue(modeId)
			return
		end

		count = math.min(#queue, mode.maxPlayers)
	end

	local players = popPlayers(modeId, count)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	ffaFillDeadline = nil
	ffaFillToken += 1
	Bindables.MatchReady:Fire(players, modeId)
end

local function tryStartAllQueues()
	for modeId, _ in queues do
		tryStartMode(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return false
	end

	local mode = getMode(modeId)
	if not mode then
		return false
	end

	if playerMode[player] == modeId then
		broadcastQueue(modeId)
		return true
	end

	removeFromQueue(player)

	if queueContains(modeId, player) then
		return false
	end

	if #queues[modeId] >= mode.maxPlayers then
		return false
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	broadcastQueue(modeId)
	tryStartMode(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	if isValidPlayer(player) then
		Remotes.QueueUpdate:FireClient(player, { status = "idle" })
	end
	broadcastQueue(modeId)
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.start()
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingConfig.DEFAULT_MODE
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		tryStartAllQueues()
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_TICK_INTERVAL)
			for modeId, queue in queues do
				if #queue > 0 then
					broadcastQueue(modeId)
				end
			end
		end
	end)
end

return MatchmakingService
