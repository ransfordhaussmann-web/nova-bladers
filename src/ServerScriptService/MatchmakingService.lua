local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local queues = {
	training = {},
	pvp = {},
	ffa = {},
}
local playerQueue = {}
local ffaTimer = {
	modeId = nil,
	token = 0,
	deadline = 0,
}

local function getQueuePlayers(modeId)
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
		return nil
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerQueue[player] = nil

	if modeId == "ffa" and ffaTimer.modeId == modeId then
		local remaining = getQueuePlayers(modeId)
		local mode = MatchModes.get(modeId)
		if #remaining < mode.minPlayers then
			ffaTimer.token += 1
			ffaTimer.modeId = nil
			ffaTimer.deadline = 0
		end
	end

	return modeId
end

local function buildPlayerEntry(player)
	return {
		name = player.DisplayName,
		userId = player.UserId,
	}
end

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queuePlayers = getQueuePlayers(modeId)
	local entries = {}
	for _, queued in queuePlayers do
		table.insert(entries, buildPlayerEntry(queued))
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	local fillRemaining = nil
	if modeId == "ffa" and ffaTimer.modeId == modeId and ffaTimer.deadline > 0 then
		fillRemaining = math.max(0, math.ceil(ffaTimer.deadline - os.clock()))
	end

	return {
		modeId = modeId,
		modeLabel = mode.label,
		status = status,
		players = entries,
		count = #entries,
		required = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillRemaining = fillRemaining,
		inQueue = playerQueue[player] == modeId,
	}
end

local function broadcastQueueUpdate(modeId)
	local queuePlayers = getQueuePlayers(modeId)
	for _, player in queuePlayers do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function startFFABroadcastLoop(modeId, token)
	task.spawn(function()
		while ffaTimer.modeId == modeId and ffaTimer.token == token do
			broadcastQueueUpdate(modeId)
			if os.clock() >= ffaTimer.deadline then
				break
			end
			task.wait(1)
		end
	end)
end

local function popPlayers(modeId, count)
	local taken = {}
	local queue = queues[modeId]
	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerQueue[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function launchMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchStateService.setBusy()
	ffaTimer.token += 1
	ffaTimer.modeId = nil
	ffaTimer.deadline = 0

	for _, player in playerList do
		Remotes.QueueUpdate:FireClient(player, {
			modeId = modeId,
			status = "starting",
			inQueue = false,
		})
	end

	Bindables.MatchReady:Fire(playerList, modeId)
end

local function tryStartMatch(modeId)
	if MatchStateService.isBusy() then
		broadcastQueueUpdate(modeId)
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queuePlayers = getQueuePlayers(modeId)
	local count = #queuePlayers

	if count < mode.minPlayers then
		broadcastQueueUpdate(modeId)
		return
	end

	if modeId == "training" then
		launchMatch(modeId, popPlayers(modeId, 1))
		return
	end

	if modeId == "pvp" then
		if count >= mode.maxPlayers then
			launchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
		else
			broadcastQueueUpdate(modeId)
		end
		return
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			launchMatch(modeId, popPlayers(modeId, mode.maxPlayers))
			return
		end

		if ffaTimer.modeId ~= modeId then
			ffaTimer.modeId = modeId
			ffaTimer.token += 1
			local token = ffaTimer.token
			ffaTimer.deadline = os.clock() + mode.fillTimeout
			startFFABroadcastLoop(modeId, token)

			task.delay(mode.fillTimeout, function()
				if token ~= ffaTimer.token or ffaTimer.modeId ~= modeId then
					return
				end
				if MatchStateService.isBusy() then
					broadcastQueueUpdate(modeId)
					return
				end

				local ready = getQueuePlayers(modeId)
				if #ready >= mode.minPlayers then
					launchMatch(modeId, popPlayers(modeId, math.min(#ready, mode.maxPlayers)))
				end
			end)
		end

		broadcastQueueUpdate(modeId)
	end
end

local function tryAllQueues()
	for modeId in queues do
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		modeId = getRecommendedModeId()
	end

	MatchmakingService.leaveQueue(player)
	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = removeFromQueue(player)
	if modeId then
		broadcastQueueUpdate(modeId)
	end

	Remotes.QueueUpdate:FireClient(player, {
		inQueue = false,
		status = "left",
	})
end

function MatchmakingService.getPlayerMode(player)
	return playerQueue[player]
end

function MatchmakingService.init(handlers)
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
		if handlers and handlers.onJoinQueue then
			handlers.onJoinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaIdle(function()
		tryAllQueues()
	end)
end

return MatchmakingService
