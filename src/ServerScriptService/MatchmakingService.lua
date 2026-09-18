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

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local ffaFillDeadline = nil
local ffaFillLoopRunning = false

local function getQueueCount(modeId)
	return #queues[modeId]
end

local function removePlayerFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerEntry[player] = nil

	if entry.modeId == "ffa" and getQueueCount("ffa") < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
	end
end

local function buildPayload(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchModes.get(entry.modeId)
	local count = getQueueCount(entry.modeId)
	local fillSecondsLeft = nil

	if entry.modeId == "ffa" and ffaFillDeadline and count >= mode.minPlayers then
		fillSecondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode.label,
		count = count,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pending = MatchStateService.isBusy(),
		fillSecondsLeft = fillSecondsLeft,
	}
end

local function sendQueueUpdate(player)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildPayload(player))
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerEntry[player] then
			sendQueueUpdate(player)
		end
	end
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	for _, player in players do
		removePlayerFromQueue(player)
		HubService.prepareForMatch(player, modeId)
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			matchStarting = true,
			modeId = modeId,
		})
	end

	Bindables.MatchReady:Fire({
		players = players,
		modeId = modeId,
	})

	broadcastQueueUpdates()
end

local function takePlayersFromQueue(modeId, amount)
	local queue = queues[modeId]
	local players = {}
	local takeCount = math.min(amount, #queue)

	for _ = 1, takeCount do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer and nextPlayer.Parent then
			playerEntry[nextPlayer] = nil
			table.insert(players, nextPlayer)
		end
	end

	return players
end

local function tryStartMode(modeId)
	if MatchStateService.isBusy() then
		return false
	end

	local mode = MatchModes.get(modeId)
	local count = getQueueCount(modeId)

	if modeId == "training" and count >= mode.minPlayers then
		launchMatch(modeId, takePlayersFromQueue(modeId, 1))
		return true
	end

	if modeId == "pvp" and count >= mode.minPlayers then
		launchMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
		return true
	end

	if modeId == "ffa" then
		if count >= mode.maxPlayers then
			ffaFillDeadline = nil
			launchMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
			return true
		end

		if ffaFillDeadline and os.clock() >= ffaFillDeadline and count >= mode.minPlayers then
			ffaFillDeadline = nil
			launchMatch(modeId, takePlayersFromQueue(modeId, count))
			return true
		end
	end

	return false
end

local function tryProcessQueues()
	if MatchStateService.isBusy() then
		return
	end

	tryStartMode("training")
	if MatchStateService.isBusy() then
		return
	end

	tryStartMode("pvp")
	if MatchStateService.isBusy() then
		return
	end

	tryStartMode("ffa")
end

local function ensureFfaFillLoop()
	if ffaFillLoopRunning then
		return
	end

	ffaFillLoopRunning = true
	task.spawn(function()
		while ffaFillLoopRunning do
			if ffaFillDeadline and getQueueCount("ffa") >= MatchModes.ffa.minPlayers then
				if os.clock() >= ffaFillDeadline then
					tryStartMode("ffa")
				else
					broadcastQueueUpdates()
				end
			end

			if not ffaFillDeadline and getQueueCount("ffa") < MatchModes.ffa.minPlayers then
				local anyQueued = false
				for modeId in queues do
					if #queues[modeId] > 0 then
						anyQueued = true
						break
					end
				end
				if not anyQueued and not MatchStateService.isBusy() then
					ffaFillLoopRunning = false
					break
				end
			end

			task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		end
	end)
end

local function scheduleFfaFill()
	local count = getQueueCount("ffa")
	if count >= MatchModes.ffa.maxPlayers then
		tryStartMode("ffa")
		return
	end

	if count >= MatchModes.ffa.minPlayers and not ffaFillDeadline then
		ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT
		ensureFfaFillLoop()
	end

	broadcastQueueUpdates()
	tryProcessQueues()
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.isValid(modeId) then
		return
	end

	if HubService.getPhase(player) ~= "hub" then
		return
	end

	if playerEntry[player] then
		removePlayerFromQueue(player)
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId, joinedAt = os.clock() }

	sendQueueUpdate(player)

	if modeId == "ffa" then
		scheduleFfaFill()
	else
		tryProcessQueues()
	end
end

function MatchmakingService.leaveQueue(player)
	if not playerEntry[player] then
		sendQueueUpdate(player)
		return
	end

	removePlayerFromQueue(player)
	sendQueueUpdate(player)
	broadcastQueueUpdates()
end

function MatchmakingService.init()
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onIdle(function()
		task.defer(tryProcessQueues)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
