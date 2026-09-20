local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

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
local ffaFillToken = 0
local pendingPollThread = nil
local initialized = false

local function isValidPlayer(player)
	return player and player.Parent == Players
end

local function getQueue(modeId)
	return queues[modeId]
end

local function queueIndex(modeId, player)
	local queue = getQueue(modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function removeFromQueue(modeId, player)
	local queue = getQueue(modeId)
	local index = queueIndex(modeId, player)
	if index then
		table.remove(queue, index)
	end
	if playerQueue[player] == modeId then
		playerQueue[player] = nil
	end
end

local function buildQueuePayload(modeId, player)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if isValidPlayer(queuedPlayer) then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	local status = "waiting"
	if MatchStateService.isBusy() then
		status = "pending"
	end

	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		count = #names,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		players = names,
		status = status,
		inQueue = playerQueue[player] == modeId,
	}
end

local function sendQueueUpdate(player)
	if not isValidPlayer(player) or not Remotes then
		return
	end

	local modeId = playerQueue[player]
	if not modeId then
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			status = "idle",
		})
		return
	end

	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
end

local function broadcastQueue(modeId)
	for _, queuedPlayer in getQueue(modeId) do
		sendQueueUpdate(queuedPlayer)
	end
end

local function broadcastAllQueues()
	for modeId in queues do
		broadcastQueue(modeId)
	end
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	local count = #queue
	if count < mode.minPlayers then
		return false
	end
	if mode.requireFull then
		return count >= mode.maxPlayers
	end
	return count >= mode.maxPlayers
end

local function popPlayers(modeId, amount)
	local queue = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(amount, #queue) do
		local player = table.remove(queue, 1)
		if isValidPlayer(player) then
			playerQueue[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function startMatchForMode(modeId)
	if MatchStateService.isBusy() then
		broadcastAllQueues()
		return false
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	local count = math.min(#queue, mode.maxPlayers)
	if mode.requireFull and #queue < mode.maxPlayers then
		return false
	end

	local players = popPlayers(modeId, count)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(queue, player)
			playerQueue[player] = modeId
		end
		return false
	end

	MatchStateService.setBusy(true)
	broadcastQueue(modeId)
	MatchReady:Fire(players, modeId)
	return true
end

local function tryStartAnyQueue()
	if MatchStateService.isBusy() then
		broadcastAllQueues()
		return
	end

	if canStartMode("training") and startMatchForMode("training") then
		return
	end
	if canStartMode("pvp") and startMatchForMode("pvp") then
		return
	end
	if canStartMode("ffa") and startMatchForMode("ffa") then
		return
	end

	broadcastAllQueues()
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
end

local function scheduleFfaFillTimer()
	cancelFfaFillTimer()
	local token = ffaFillToken
	local queue = getQueue("ffa")
	if #queue < MatchModes.get("ffa").minPlayers then
		return
	end

	task.spawn(function()
		task.wait(MatchmakingConfig.FFA_FILL_TIMEOUT)
		if token ~= ffaFillToken then
			return
		end
		if MatchStateService.isBusy() then
			return
		end

		local ffaQueue = getQueue("ffa")
		local mode = MatchModes.get("ffa")
		if #ffaQueue >= mode.minPlayers and #ffaQueue < mode.maxPlayers then
			startMatchForMode("ffa")
		end
	end)
end

function MatchmakingService.leaveQueue(player)
	if not isValidPlayer(player) then
		return
	end

	local modeId = playerQueue[player]
	if not modeId then
		sendQueueUpdate(player)
		return
	end

	removeFromQueue(modeId, player)
	if modeId == "ffa" then
		cancelFfaFillTimer()
		scheduleFfaFillTimer()
	end

	sendQueueUpdate(player)
	broadcastQueue(modeId)
	tryStartAnyQueue()
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidPlayer(player) then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if playerQueue[player] == modeId then
		sendQueueUpdate(player)
		return
	end

	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	sendQueueUpdate(player)
	broadcastQueue(modeId)

	if modeId == "ffa" then
		if canStartMode("ffa") then
			cancelFfaFillTimer()
			tryStartAnyQueue()
		else
			scheduleFfaFillTimer()
		end
	else
		tryStartAnyQueue()
	end
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

function MatchmakingService.onMatchEnded()
	MatchStateService.setBusy(false)
	cancelFfaFillTimer()
	task.defer(function()
		tryStartAnyQueue()
		if not MatchStateService.isBusy() then
			local ffaQueue = getQueue("ffa")
			local mode = MatchModes.get("ffa")
			if #ffaQueue >= mode.minPlayers and #ffaQueue < mode.maxPlayers then
				scheduleFfaFillTimer()
			end
		end
	end)
end

function MatchmakingService.init(deps)
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = MatchmakingService.getSuggestedModeId()
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = playerQueue[player]
		if modeId then
			removeFromQueue(modeId, player)
			if modeId == "ffa" then
				cancelFfaFillTimer()
				scheduleFfaFillTimer()
			end
			broadcastQueue(modeId)
		end
	end)

	if not pendingPollThread then
		pendingPollThread = task.spawn(function()
			while true do
				task.wait(MatchmakingConfig.PENDING_POLL_INTERVAL)
				if MatchStateService.isBusy() then
					broadcastAllQueues()
				end
			end
		end)
	end

	if deps and deps.onBeforeMatch then
		MatchReady.Event:Connect(function(players, modeId)
			for _, player in players do
				deps.onBeforeMatch(player, modeId)
			end
		end)
	end

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
