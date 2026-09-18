local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes, Bindables
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTimers = {}
local pendingStarts = {}

local function getQueueList(modeId)
	local list = {}
	for player, _ in pairs(queues[modeId]) do
		if player.Parent and HubService.getPhase(player) == "hub" then
			table.insert(list, player)
		else
			queues[modeId][player] = nil
			playerQueue[player] = nil
		end
	end
	return list
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local members = getQueueList(modeId)
	local names = {}
	for _, member in members do
		table.insert(names, member.Name)
	end

	local payload = {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #members,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		names = names,
		inQueue = playerQueue[player] == modeId,
		pending = MatchStateService.isArenaBusy(),
	}

	if modeId == "ffa" and fillTimers[modeId] then
		payload.fillEndsAt = fillTimers[modeId].endsAt
	end

	return payload
end

local function broadcastQueue(modeId)
	local members = getQueueList(modeId)
	for _, player in members do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastAllQueues()
	for modeId, _ in pairs(queues) do
		broadcastQueue(modeId)
	end
end

local function clearFillTimer(modeId)
	local timer = fillTimers[modeId]
	if timer then
		timer.token = nil
		fillTimers[modeId] = nil
	end
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	queues[modeId][player] = nil
	playerQueue[player] = nil

	local remaining = getQueueList(modeId)
	if #remaining < MatchModes.get(modeId).minPlayers then
		clearFillTimer(modeId)
	end

	broadcastQueue(modeId)

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			modeId = modeId,
		})
	end
end

local function popQueueMembers(modeId, count)
	local members = getQueueList(modeId)
	local picked = {}
	for i = 1, math.min(count, #members) do
		table.insert(picked, members[i])
	end

	for _, player in picked do
		queues[modeId][player] = nil
		playerQueue[player] = nil
	end

	clearFillTimer(modeId)
	broadcastAllQueues()
	return picked
end

local function leaveHubForMatch(player)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	HubService.leaveHubForArena(player)
end

local function fireMatchReady(modeId, playerList)
	for _, player in playerList do
		leaveHubForMatch(player)
	end
	MatchReady:Fire(modeId, playerList)
end

local function tryStartMatch(modeId, forceStart)
	if MatchStateService.isArenaBusy() then
		pendingStarts[modeId] = true
		broadcastQueue(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local members = getQueueList(modeId)
	if #members < mode.minPlayers then
		return
	end

	if modeId == "ffa" and not forceStart and #members < mode.maxPlayers then
		if not fillTimers[modeId] then
			local token = {}
			fillTimers[modeId] = {
				endsAt = Workspace:GetServerTimeNow() + MatchmakingConfig.FFA_FILL_TIMEOUT,
				token = token,
			}
			broadcastQueue(modeId)

			task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
				local timer = fillTimers[modeId]
				if not timer or timer.token ~= token then
					return
				end
				fillTimers[modeId] = nil
				tryStartMatch(modeId, true)
			end)
		end
		return
	end

	local count = mode.maxPlayers
	if modeId == "ffa" then
		count = math.min(#members, mode.maxPlayers)
	else
		count = mode.maxPlayers
	end

	local players = popQueueMembers(modeId, count)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return
	end

	clearFillTimer(modeId)
	pendingStarts[modeId] = nil
	fireMatchReady(modeId, players)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if playerQueue[player] then
		if playerQueue[player] == modeId then
			return true
		end
		removeFromQueue(player)
	end
	if HubService.getPhase(player) ~= "hub" then
		return false
	end

	queues[modeId][player] = true
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	removeFromQueue(player)
end

function MatchmakingService.getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getRecommendedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		removeFromQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		for _, modeId in { "training", "pvp", "ffa" } do
			pendingStarts[modeId] = nil
			tryStartMatch(modeId)
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
