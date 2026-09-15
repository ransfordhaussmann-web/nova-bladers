--[[
	MatchmakingService — per-mode queues, FFA fill timeout, pending when arena is busy.
]]

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
local ffaFillToken = 0
local pendingLaunch = nil

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function playerInQueue(player)
	return playerMode[player] ~= nil
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local members = {}
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			table.insert(members, queuedPlayer.Name)
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	elseif mode and #members >= mode.minPlayers then
		status = "ready"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		players = members,
		count = #members,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status,
	}
end

local function broadcastQueue(modeId)
	local payload = buildQueuePayload(modeId, nil)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return nil
	end

	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerMode[player] = nil
	broadcastQueue(modeId)
	return modeId
end

local function takePlayers(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	local limit = math.min(count, #queue)

	for _ = 1, limit do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end

	broadcastQueue(modeId)
	return taken
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	for _, player in playerList do
		HubService.enterMatch(player, modeId)
	end

	MatchReady:Fire(playerList, modeId)
end

local function tryLaunchMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queueSize = getQueueSize(modeId)
	if queueSize < mode.minPlayers then
		return false
	end

	local playerList = takePlayers(modeId, mode.maxPlayers)
	if #playerList < mode.minPlayers then
		for index = #playerList, 1, -1 do
			local player = playerList[index]
			table.remove(playerList, index)
			table.insert(queues[modeId], 1, player)
			playerMode[player] = modeId
		end
		broadcastQueue(modeId)
		return false
	end

	if MatchStateService.isBusy() then
		pendingLaunch = {
			modeId = modeId,
			players = playerList,
		}
		for _, player in playerList do
			HubService.setQueuePending(player, modeId)
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
		return true
	end

	launchMatch(modeId, playerList)
	return true
end

local function cancelFfaFill()
	ffaFillToken += 1
end

local function scheduleFfaFill()
	cancelFfaFill()
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		if getQueueSize("ffa") >= MatchModes.ffa.minPlayers then
			tryLaunchMode("ffa")
		end
	end)
end

local function checkQueues()
	for _, mode in MatchModes.getAll() do
		if mode.id ~= "ffa" and getQueueSize(mode.id) >= mode.minPlayers then
			tryLaunchMode(mode.id)
		end
	end
end

local function processPending()
	if not pendingLaunch or MatchStateService.isBusy() then
		return
	end

	local launch = pendingLaunch
	pendingLaunch = nil
	launchMatch(launch.modeId, launch.players)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false, "invalid_mode"
	end
	if not player.Parent or HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end
	if playerInQueue(player) then
		return false, "already_queued"
	end
	if MatchStateService.isBusy() and modeId == "training" then
		-- Training can still queue while arena is busy; it waits as pending.
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	HubService.enterQueue(player, modeId)

	local payload = buildQueuePayload(modeId, player)
	Remotes.QueueUpdate:FireClient(player, payload)
	broadcastQueue(modeId)

	if modeId == "ffa" then
		local ffaSize = getQueueSize("ffa")
		if ffaSize == MatchModes.ffa.minPlayers then
			scheduleFfaFill()
		elseif ffaSize >= MatchModes.ffa.maxPlayers then
			cancelFfaFill()
			tryLaunchMode("ffa")
		elseif ffaSize < MatchModes.ffa.minPlayers then
			cancelFfaFill()
		end
	else
		tryLaunchMode(modeId)
	end

	return true
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if not modeId then
		return false
	end

	if modeId == "ffa" and getQueueSize("ffa") < MatchModes.ffa.minPlayers then
		cancelFfaFill()
	end

	HubService.returnPlayerToHub(player)
	return true
end

function MatchmakingService.onMatchEnded()
	task.defer(function()
		processPending()
		checkQueues()
	end)
end

function MatchmakingService.getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.start()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getSuggestedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
		if pendingLaunch then
			for index, queuedPlayer in pendingLaunch.players do
				if queuedPlayer == player then
					table.remove(pendingLaunch.players, index)
					break
				end
			end
			if #pendingLaunch.players < MatchModes.get(pendingLaunch.modeId).minPlayers then
				for _, remaining in pendingLaunch.players do
					table.insert(queues[pendingLaunch.modeId], remaining)
					playerMode[remaining] = pendingLaunch.modeId
					HubService.enterQueue(remaining, pendingLaunch.modeId)
				end
				pendingLaunch = nil
			end
		end
	end)

	MatchStateService.onFreed(function()
		processPending()
		checkQueues()
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
