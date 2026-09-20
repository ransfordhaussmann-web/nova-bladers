local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingService = {}

local Remotes

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local fillTokens = {}
local callbacks = {}

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	local queue = getQueue(entry.modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
end

local function playerName(player)
	return player.DisplayName or player.Name
end

local function buildQueuePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, playerName(queuedPlayer))
		end
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		players = names,
		count = #names,
		needed = mode.maxPlayers,
		minPlayers = mode.minPlayers,
		status = status or "waiting",
	}
end

local function broadcastQueue(modeId, status)
	local payload = buildQueuePayload(modeId, status)
	for _, queuedPlayer in getQueue(modeId) do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function cancelFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function startFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode.fillTimeout then
		return
	end

	cancelFillTimer(modeId)
	local token = fillTokens[modeId] or 0

	task.delay(mode.fillTimeout, function()
		if fillTokens[modeId] ~= token then
			return
		end

		local queue = getQueue(modeId)
		if #queue >= mode.minPlayers then
			MatchmakingService.tryStartMatch(modeId)
		end
	end)
end

local function canStart(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	return #queue >= mode.minPlayers
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local roster = {}

	for i = 1, count do
		local player = queue[1]
		table.remove(queue, 1)
		if player and player.Parent then
			table.insert(roster, player)
			playerQueue[player] = nil
		end
	end

	return roster
end

function MatchmakingService.tryStartMatch(modeId)
	if not canStart(modeId) then
		return false
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId, "pending")
		return false
	end

	local roster = takePlayers(modeId)
	if #roster == 0 then
		return false
	end

	cancelFillTimer(modeId)
	MatchStateService.setBusy(true)

	if callbacks.onMatchReady then
		callbacks.onMatchReady(roster, modeId)
	end

	broadcastAllQueues()
	return true
end

local function processPendingQueues()
	for modeId in queues do
		if canStart(modeId) then
			MatchmakingService.tryStartMatch(modeId)
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	if modeId == "auto" then
		modeId = MatchModes.resolveAuto(#Players:GetPlayers()).id
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	if #queue >= mode.maxPlayers then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = { modeId = modeId }

	if #queue == 1 and mode.fillTimeout then
		startFillTimer(modeId)
	end

	broadcastQueue(modeId)

	if #queue >= mode.maxPlayers or (#queue >= mode.minPlayers and not mode.fillTimeout) then
		MatchmakingService.tryStartMatch(modeId)
	end
end

function MatchmakingService.leaveQueue(player)
	local entry = playerQueue[player]
	if not entry then
		return
	end

	removeFromQueue(player)
	broadcastQueue(entry.modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(processPendingQueues)
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.init(options)
	callbacks = options or {}

	Remotes, _ = RemotesSetup.ensure()
	local _, Bindables = RemotesSetup.ensure()
	local MatchEnded = Bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.PENDING_RETRY_INTERVAL)
			if not MatchStateService.isBusy() then
				processPendingQueues()
			else
				for modeId in queues do
					if canStart(modeId) then
						broadcastQueue(modeId, "pending")
					end
				end
			end
		end
	end)

	print("[MatchmakingService] Queue system ready")
end

return MatchmakingService
