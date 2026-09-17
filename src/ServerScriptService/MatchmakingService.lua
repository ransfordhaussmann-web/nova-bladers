local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
local fillTokens = {}
local pendingMatch = nil
local started = false

local function getQueueList(modeId)
	local list = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(list, player)
		end
	end
	return list
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for i, queued in queue do
		if queued == player then
			table.remove(queue, i)
			break
		end
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local members = getQueueList(modeId)
	local names = {}
	for _, member in members do
		table.insert(names, member.DisplayName)
	end

	local status = "waiting"
	if pendingMatch and pendingMatch.modeId == modeId then
		for _, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				status = "pending"
				break
			end
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = #members,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		names = names,
		status = status,
	}
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
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function takePlayers(modeId, count)
	local queue = getQueueList(modeId)
	local taken = {}
	for i = 1, math.min(count, #queue) do
		table.insert(taken, queue[i])
	end

	for _, player in taken do
		removeFromQueue(player)
	end

	return taken
end

local function launchMatch(players, modeId)
	pendingMatch = nil
	MatchStateService.setBusy(true)

	for _, player in players do
		if player.Parent and HubService.prepareForMatch then
			HubService.prepareForMatch(player)
		end
	end

	MatchReady:Fire(players, modeId)
	broadcastAllQueues()
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueueList(modeId)
	if #queue < mode.minPlayers then
		return
	end

	local playerCount = math.min(#queue, mode.maxPlayers)
	local players = takePlayers(modeId, playerCount)

	if MatchStateService.isBusy() then
		pendingMatch = {
			modeId = modeId,
			players = players,
		}
		for _, player in players do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
			end
		end
		return
	end

	launchMatch(players, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout or MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTokens[modeId] ~= token then
			return
		end
		if #getQueueList(modeId) >= mode.minPlayers then
			tryStartMatch(modeId)
		end
	end)
end

local function onQueueChanged(modeId)
	broadcastQueue(modeId)

	local mode = MatchModes.get(modeId)
	local count = #getQueueList(modeId)
	if not mode then
		return
	end

	if count >= mode.maxPlayers then
		tryStartMatch(modeId)
		return
	end

	if count >= mode.minPlayers and not mode.fillTimeout then
		tryStartMatch(modeId)
		return
	end

	if mode.fillTimeout and count >= mode.minPlayers and count == mode.minPlayers then
		scheduleFillTimeout(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchModes.isValid(modeId) then
		return false
	end
	if playerQueue[player] == modeId then
		return true
	end
	if MatchStateService.isBusy() and HubService.getPhase(player) == "arena" then
		return false
	end

	MatchmakingService.leaveQueue(player)

	playerQueue[player] = modeId
	table.insert(queues[modeId], player)

	if HubService.enterQueue then
		HubService.enterQueue(player, modeId)
	end

	Remotes.QueueJoin:FireClient(player, buildQueuePayload(modeId, player))
	onQueueChanged(modeId)
	return true
end

function MatchmakingService.leaveQueue(player)
	if pendingMatch then
		for i, pendingPlayer in pendingMatch.players do
			if pendingPlayer == player then
				table.remove(pendingMatch.players, i)
				Remotes.QueueLeave:FireClient(player)
				if HubService.leaveQueue then
					HubService.leaveQueue(player)
				end

				local modeId = pendingMatch.modeId
				local mode = MatchModes.get(modeId)
				local remaining = pendingMatch.players
				if not mode or #remaining < mode.minPlayers then
					pendingMatch = nil
					for _, remainingPlayer in remaining do
						if remainingPlayer.Parent then
							table.insert(queues[modeId], remainingPlayer)
							playerQueue[remainingPlayer] = modeId
							if HubService.enterQueue then
								HubService.enterQueue(remainingPlayer, modeId)
							end
						end
					end
					onQueueChanged(modeId)
				end
				return
			end
		end
	end

	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	removeFromQueue(player)

	if HubService.leaveQueue then
		HubService.leaveQueue(player)
	end

	Remotes.QueueLeave:FireClient(player)
	broadcastQueue(modeId)
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

function MatchmakingService.start()
	if started then
		return
	end
	started = true

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
		MatchmakingService.leaveQueue(player)

		if pendingMatch then
			for i, pendingPlayer in pendingMatch.players do
				if pendingPlayer == player then
					table.remove(pendingMatch.players, i)
					break
				end
			end
			if #pendingMatch.players == 0 then
				pendingMatch = nil
			end
		end
	end)

	MatchStateService.onArenaFreed(function()
		if pendingMatch and #pendingMatch.players > 0 then
			local match = pendingMatch
			pendingMatch = nil
			launchMatch(match.players, match.modeId)
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
