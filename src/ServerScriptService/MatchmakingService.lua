local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local handlers = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillDeadline = nil
local ffaFillToken = 0
local pendingMatch = nil

local function getQueue(modeId)
	return queues[modeId] or queues.training
end

local function countQueue(modeId)
	return #getQueue(modeId)
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil

	if modeId == "ffa" and countQueue("ffa") < MatchModes.ffa.minPlayers then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end
end

local function buildQueuePayload(player, modeId, pendingArena)
	local mode = MatchModes.get(modeId)
	local inQueue = countQueue(modeId)
	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = inQueue,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pendingArena = pendingArena == true,
	}

	if modeId == "ffa" and ffaFillDeadline and inQueue >= mode.minPlayers then
		payload.fillSecondsLeft = math.max(0, math.ceil(ffaFillDeadline - os.clock()))
	end

	return payload
end

local function broadcastQueue(modeId, pendingArena)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			Remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId, pendingArena))
		end
	end
end

local function clearQueueUI(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function takePlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local count = math.min(#queue, mode.maxPlayers)
	local taken = {}

	for _ = 1, count do
		local nextPlayer = table.remove(queue, 1)
		if nextPlayer then
			playerMode[nextPlayer] = nil
			table.insert(taken, nextPlayer)
		end
	end

	if modeId == "ffa" then
		ffaFillDeadline = nil
		ffaFillToken += 1
	end

	return taken
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local inQueue = countQueue(modeId)

	if inQueue < mode.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if inQueue >= mode.maxPlayers then
			return true
		end
		if ffaFillDeadline and os.clock() >= ffaFillDeadline then
			return true
		end
		return false
	end

	return inQueue >= mode.minPlayers
end

local function launchMatch(modeId, playerList)
	for _, player in playerList do
		clearQueueUI(player)
	end

	if MatchStateService.isArenaBusy() then
		pendingMatch = {
			modeId = modeId,
			players = playerList,
		}
		for _, player in playerList do
			if player.Parent then
				Remotes.QueueUpdate:FireClient(player, {
					inQueue = true,
					modeId = modeId,
					modeLabel = MatchModes.get(modeId).label,
					playersInQueue = #playerList,
					minPlayers = MatchModes.get(modeId).minPlayers,
					maxPlayers = MatchModes.get(modeId).maxPlayers,
					pendingArena = true,
				})
			end
		end
		return
	end

	pendingMatch = nil
	Bindables.MatchReady:Fire(playerList)
end

local function tryStartMatch(modeId)
	if not canStartMode(modeId) then
		return
	end

	local playerList = takePlayers(modeId)
	if #playerList == 0 then
		return
	end

	launchMatch(modeId, playerList)
	broadcastQueue(modeId, false)
end

local function scheduleFfaFill()
	local mode = MatchModes.ffa
	if countQueue("ffa") < mode.minPlayers then
		return
	end

	if ffaFillDeadline then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillDeadline = os.clock() + MatchmakingConfig.FFA_FILL_TIMEOUT

	broadcastQueue("ffa", MatchStateService.isArenaBusy())

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken then
			return
		end
		tryStartMatch("ffa")
	end)
end

local function filterActivePlayers(playerList)
	local active = {}
	for _, queuedPlayer in playerList do
		if queuedPlayer.Parent then
			table.insert(active, queuedPlayer)
		end
	end
	return active
end

local function processPending()
	if not pendingMatch then
		return
	end
	if MatchStateService.isArenaBusy() then
		return
	end

	local match = pendingMatch
	pendingMatch = nil

	local players = filterActivePlayers(match.players)
	if #players == 0 then
		return
	end

	Bindables.MatchReady:Fire(players)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end

	local modeId = playerMode[player]
	removeFromQueue(player)
	clearQueueUI(player)
	broadcastQueue(modeId, MatchStateService.isArenaBusy())
end

function MatchmakingService.joinQueue(player, modeId)
	if MatchStateService.isPlayerInMatch(player) then
		return
	end

	if typeof(modeId) ~= "string" then
		modeId = handlers.getActiveMode and handlers.getActiveMode() or "training"
	end

	if not MatchModes.get(modeId) then
		modeId = "training"
	end

	if playerMode[player] == modeId then
		return
	end

	MatchmakingService.leaveQueue(player)

	if handlers.leaveHub then
		handlers.leaveHub(player)
	end

	table.insert(getQueue(modeId), player)
	playerMode[player] = modeId

	broadcastQueue(modeId, MatchStateService.isArenaBusy())

	if modeId == "ffa" then
		scheduleFfaFill()
	end

	tryStartMatch(modeId)
end

function MatchmakingService.init(newHandlers)
	handlers = newHandlers or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
		if handlers.enterHub then
			handlers.enterHub(player)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onArenaFree(function()
		processPending()
		for modeId in queues do
			if modeId == "ffa" then
				scheduleFfaFill()
			end
			tryStartMatch(modeId)
		end
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
