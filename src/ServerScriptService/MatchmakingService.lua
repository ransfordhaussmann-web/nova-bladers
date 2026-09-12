local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchState = require(script.Parent.MatchState)
local GameMatchState = require(script.Parent.GameMatchState)

local MatchmakingService = {}

local Remotes
local MatchReady
local hubApi = {}
local started = false
local ffaFillTask = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function playerInHub(player)
	if hubApi.getPhase then
		return hubApi.getPhase(player) == "hub"
	end
	return true
end

local function broadcastQueue(modeId)
	local queue = MatchState.snapshot(modeId)
	for _, player in queue do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, MatchState.buildUpdatePayload(player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in MatchmakingConfig.MODES do
		broadcastQueue(modeId)
	end
end

local function leaveHubForArena(player)
	if hubApi.leaveHubForArena then
		hubApi.leaveHubForArena(player)
	end
end

local function launchMatch(modeId, players)
	local mode = getModeConfig(modeId)
	local roster = {}
	for index = 1, math.min(#players, mode.maxPlayers) do
		table.insert(roster, players[index])
	end

	for _, player in roster do
		MatchState.dequeue(player)
		leaveHubForArena(player)
	end

	broadcastAllQueues()
	MatchReady:Fire(roster)
end

local function tryStartMode(modeId, forceFfaStart)
	if GameMatchState.isBusy() then
		return false
	end

	local mode = getModeConfig(modeId)
	local players = MatchState.snapshot(modeId)
	if #players < mode.minPlayers then
		return false
	end

	if modeId == "ffa" and #players < mode.maxPlayers and not forceFfaStart then
		return false
	end

	launchMatch(modeId, players)
	return true
end

local function scheduleFfaFill()
	if ffaFillTask then
		return
	end

	local mode = MatchmakingConfig.MODES.ffa
	local token = MatchState.bumpFfaFillToken()
	ffaFillTask = task.delay(mode.fillTimeout, function()
		ffaFillTask = nil
		if token ~= MatchState.getFfaFillToken() then
			return
		end
		if GameMatchState.isBusy() then
			local players = MatchState.snapshot("ffa")
			if #players >= mode.minPlayers then
				MatchState.setPending(players)
				broadcastQueue("ffa")
			end
			return
		end
		tryStartMode("ffa", true)
	end)
end

local function cancelFfaFill()
	MatchState.bumpFfaFillToken()
	ffaFillTask = nil
end

local function evaluateQueues()
	if GameMatchState.isBusy() then
		for modeId in MatchmakingConfig.MODES do
			local players = MatchState.snapshot(modeId)
			local mode = getModeConfig(modeId)
			if #players >= mode.minPlayers then
				MatchState.setPending(players)
				broadcastQueue(modeId)
			end
		end
		return
	end

	for _, modeId in { "training", "pvp", "ffa" } do
		local mode = getModeConfig(modeId)
		local players = MatchState.snapshot(modeId)
		if #players > 0 then
			if modeId == "ffa" then
				if #players >= mode.maxPlayers then
					cancelFfaFill()
					launchMatch(modeId, players)
					return
				end
				if #players >= mode.minPlayers then
					scheduleFfaFill()
				else
					cancelFfaFill()
				end
			elseif #players >= mode.minPlayers then
				launchMatch(modeId, players)
				return
			end
		end
	end
end

local function sendQueueUpdate(player)
	Remotes.QueueUpdate:FireClient(player, MatchState.buildUpdatePayload(player))
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if not playerInHub(player) then
		return
	end
	if GameMatchState.isBusy() and MatchState.isQueued(player) then
		return
	end

	MatchState.enqueue(player, modeId)
	sendQueueUpdate(player)
	broadcastQueue(modeId)
	evaluateQueues()
end

function MatchmakingService.leaveQueue(player)
	if not MatchState.isQueued(player) then
		return
	end

	local modeId = MatchState.getPlayerMode(player)
	MatchState.dequeue(player)
	if modeId == "ffa" and #MatchState.snapshot("ffa") < MatchmakingConfig.MODES.ffa.minPlayers then
		cancelFfaFill()
	end
	sendQueueUpdate(player)
	if modeId then
		broadcastQueue(modeId)
	end
end

function MatchmakingService.onArenaFreed()
	for modeId in MatchmakingConfig.MODES do
		local players = MatchState.snapshot(modeId)
		MatchState.clearPending(players)
	end
	broadcastAllQueues()
	evaluateQueues()
end

function MatchmakingService.onPlayerRemoving(player)
	MatchmakingService.leaveQueue(player)
end

function MatchmakingService.start(api)
	if started then
		return
	end
	started = true
	hubApi = api or {}

	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = "training"
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.onPlayerRemoving(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
			if not GameMatchState.isBusy() then
				evaluateQueues()
			end
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
