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
local MatchEnded

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local pendingGroups = {}
local fillTimers = {}
local fillToken = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	if queue then
		for i, queuedPlayer in queue do
			if queuedPlayer == player then
				table.remove(queue, i)
				break
			end
		end
	end

	playerQueue[player] = nil

	local mode = MatchModes.get(entry.modeId)
	if mode and mode.waitForFill then
		fillToken[entry.modeId] = (fillToken[entry.modeId] or 0) + 1
		fillTimers[entry.modeId] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId) or {}
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.Name)
		end
	end

	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		players = names,
		count = #names,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		position = position,
		status = status,
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	if not queue then
		return
	end

	for _, player in queue do
		if player.Parent and playerQueue[player] then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function popPlayers(modeId, count)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, count do
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

	if MatchStateService.isBusy() then
		table.insert(pendingGroups, { modeId = modeId, players = playerList })
		for _, player in playerList do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					modeId = modeId,
					modeLabel = MatchModes.get(modeId).label,
					players = {},
					count = 0,
					minPlayers = 0,
					maxPlayers = 0,
					position = 0,
					status = "pending",
				})
			end
		end
		return
	end

	for _, player in playerList do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, {
				modeId = modeId,
				status = "starting",
			})
		end
	end

	MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or not queue then
		return
	end

	while #queue >= mode.maxPlayers do
		local group = popPlayers(modeId, mode.maxPlayers)
		launchMatch(modeId, group)
		broadcastQueue(modeId)
	end

	if not mode.waitForFill and #queue >= mode.minPlayers then
		local group = popPlayers(modeId, #queue)
		launchMatch(modeId, group)
		broadcastQueue(modeId)
	end
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.waitForFill then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		fillTimers[modeId] = nil
		return
	end

	if fillTimers[modeId] then
		return
	end

	fillToken[modeId] = (fillToken[modeId] or 0) + 1
	local token = fillToken[modeId]
	fillTimers[modeId] = true

	local timeout = mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT
	task.delay(timeout, function()
		fillTimers[modeId] = nil
		if token ~= fillToken[modeId] then
			return
		end

		local currentQueue = getQueue(modeId)
		if not currentQueue or #currentQueue < mode.minPlayers then
			return
		end

		local group = popPlayers(modeId, #currentQueue)
		launchMatch(modeId, group)
		broadcastQueue(modeId)
	end)
end

local function processPending()
	if MatchStateService.isBusy() or #pendingGroups == 0 then
		return
	end

	local nextGroup = table.remove(pendingGroups, 1)
	if nextGroup and #nextGroup.players > 0 then
		launchMatch(nextGroup.modeId, nextGroup.players)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	if playerQueue[player] then
		if playerQueue[player].modeId == modeId then
			return
		end
		removeFromQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = { modeId = modeId }

	broadcastQueue(modeId)
	tryStartMatch(modeId)
	scheduleFillTimer(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player].modeId
	removeFromQueue(player)
	Remotes.QueueUpdate:FireClient(player, { status = "left" })
	broadcastQueue(modeId)
end

function MatchmakingService.isQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			local modeId = playerQueue[player].modeId
			removeFromQueue(player)
			broadcastQueue(modeId)
			tryStartMatch(modeId)
			scheduleFillTimer(modeId)
		end
	end)

	MatchEnded.Event:Connect(function()
		broadcastAllQueues()
		processPending()
	end)
end

return MatchmakingService
