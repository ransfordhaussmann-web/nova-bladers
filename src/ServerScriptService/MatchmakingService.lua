local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local handlers = {}
local ffaFillToken = 0

local Remotes
local Bindables

local function getMessage(modeId, status, count)
	if status == "pending" then
		return "Arena belegt — warte..."
	end

	local mode = MatchModes.get(modeId)
	if count < mode.minPlayers then
		return string.format("Warte auf Spieler (%d/%d)...", count, mode.minPlayers)
	end
	if modeId == "ffa" and count < mode.maxPlayers then
		return string.format("Match startet bald (%d/%d)...", count, mode.maxPlayers)
	end
	return "Match startet..."
end

local function buildUpdatePayload(modeId, status)
	local mode = MatchModes.get(modeId)
	local count = #queues[modeId]
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		players = count,
		required = mode.minPlayers,
		max = mode.maxPlayers,
		status = status,
		message = getMessage(modeId, status, count),
	}
end

local function getQueueStatus(modeId)
	local mode = MatchModes.get(modeId)
	local count = #queues[modeId]
	if count >= mode.minPlayers and MatchStateService.isArenaBusy() then
		return "pending"
	end
	return "waiting"
end

local function broadcastQueueUpdates(modeId)
	local status = getQueueStatus(modeId)
	local payload = buildUpdatePayload(modeId, status)
	for _, queuedPlayer in queues[modeId] do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function clearPlayerFromQueues(player)
	local modeId = playerQueue[player]
	if not modeId then
		return nil
	end

	playerQueue[player] = nil
	local queue = queues[modeId]
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	if modeId == "ffa" and #queues.ffa < MatchModes.ffa.minPlayers then
		ffaFillToken += 1
	end

	return modeId
end

local function popPlayers(modeId, count)
	local players = {}
	for _ = 1, count do
		local nextPlayer = table.remove(queues[modeId], 1)
		if not nextPlayer then
			break
		end
		playerQueue[nextPlayer] = nil
		table.insert(players, nextPlayer)
	end
	return players
end

local function launchMatch(modeId, playerList)
	for _, matchedPlayer in playerList do
		if matchedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(matchedPlayer, { inQueue = false })
			if handlers.leaveHubForArena then
				handlers.leaveHubForArena(matchedPlayer)
			end
		end
	end

	broadcastQueueUpdates(modeId)
	Bindables.MatchReady:Fire(playerList, modeId)
end

local function startMatch(modeId, takeCount)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if #queues[modeId] < mode.minPlayers then
		return false
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return false
	end

	local count = math.clamp(takeCount, mode.minPlayers, math.min(#queues[modeId], mode.maxPlayers))
	local players = popPlayers(modeId, count)
	if #players < mode.minPlayers then
		for _, queuedPlayer in players do
			table.insert(queues[modeId], queuedPlayer)
			playerQueue[queuedPlayer] = modeId
		end
		return false
	end

	launchMatch(modeId, players)
	return true
end

local function scheduleFfaFill()
	ffaFillToken += 1
	local token = ffaFillToken

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end

		local mode = MatchModes.ffa
		local count = #queues.ffa
		if count < mode.minPlayers then
			return
		end

		startMatch("ffa", math.min(count, mode.maxPlayers))
	end)
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local count = #queues[modeId]
	if count < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	if modeId == "training" then
		startMatch("training", 1)
	elseif modeId == "pvp" then
		startMatch("pvp", 2)
	elseif modeId == "ffa" then
		if count >= mode.maxPlayers then
			ffaFillToken += 1
			startMatch("ffa", mode.maxPlayers)
		elseif count == mode.minPlayers then
			scheduleFfaFill()
			broadcastQueueUpdates("ffa")
		else
			broadcastQueueUpdates("ffa")
		end
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end
	if not player or not player.Parent then
		return
	end
	if handlers.getPhase and handlers.getPhase(player) ~= "hub" then
		return
	end

	local previousMode = clearPlayerFromQueues(player)
	if previousMode and previousMode ~= modeId then
		broadcastQueueUpdates(previousMode)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdates(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	local modeId = clearPlayerFromQueues(player)
	if not modeId then
		return
	end

	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
	broadcastQueueUpdates(modeId)
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers
	Remotes, Bindables = RemotesSetup.ensure()

	MatchStateService.onArenaFree(function()
		for _, mode in MatchModes.all() do
			tryStartMatch(mode.id)
		end
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
