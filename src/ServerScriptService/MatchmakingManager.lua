local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(ReplicatedStorage.NovaBladers.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local MatchmakingManager = {}

local Remotes, Bindables
local HubService
local getActiveModeId

local arenaBusy = false
local queues = {}
local playerQueue = {}
local fillTokens = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueSize(modeId)
	return #ensureQueue(modeId)
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	local queue = ensureQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerQueue[player] = nil
	fillTokens[modeId] = nil
end

local function getQueueStatus(modeId, queueSize)
	local mode = MatchmakingConfig.MODES[modeId]
	if arenaBusy and queueSize >= mode.minPlayers then
		return "pending"
	end
	if fillTokens[modeId] and queueSize >= mode.minPlayers then
		return "filling"
	end
	return "waiting"
end

local function broadcastQueue(modeId)
	local queue = ensureQueue(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return
	end

	local status = getQueueStatus(modeId, #queue)

	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			local payload = MatchmakingService.buildQueuePayload(modeId, #queue, status, nil)
			Remotes.QueueUpdate:FireClient(queuedPlayer, payload)
		end
	end
end

local function sendQueueClear(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
end

local function setArenaPhase(player)
	if HubService and HubService.leaveHubForArena then
		HubService.leaveHubForArena(player)
	end
end

local function startMatch(modeId, playerList)
	for _, player in playerList do
		removeFromQueue(player)
		sendQueueClear(player)
		setArenaPhase(player)
	end

	Bindables.MatchReady:Fire({
		mode = modeId,
		players = playerList,
	})
end

local function takePlayersFromQueue(modeId, count)
	local queue = ensureQueue(modeId)
	local players = {}
	for i = 1, math.min(count, #queue) do
		table.insert(players, queue[i])
	end
	return players
end

local function tryStartMatch(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	if not mode then
		return false
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return false
	end

	if arenaBusy then
		return false
	end

	if #queue >= mode.maxPlayers then
		startMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
		return true
	end

	if mode.fillTimeout > 0 then
		if not fillTokens[modeId] then
			fillTokens[modeId] = true
			broadcastQueue(modeId)

			task.delay(mode.fillTimeout, function()
				fillTokens[modeId] = nil
				if arenaBusy then
					return
				end

				local currentQueue = ensureQueue(modeId)
				if #currentQueue >= mode.minPlayers then
					startMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
				end
			end)
		end
		return true
	end

	startMatch(modeId, takePlayersFromQueue(modeId, mode.maxPlayers))
	return true
end

local function tryStartAllQueues()
	for modeId in MatchmakingConfig.MODES do
		if arenaBusy then
			break
		end
		if getQueueSize(modeId) > 0 then
			tryStartMatch(modeId)
		end
	end
end

function MatchmakingManager.joinQueue(player, modeId)
	if not MatchmakingService.isValidMode(modeId) then
		return false
	end
	if playerQueue[player] then
		MatchmakingManager.leaveQueue(player)
	end

	local queue = ensureQueue(modeId)
	if #queue >= MatchmakingConfig.MODES[modeId].maxPlayers then
		return false
	end

	table.insert(queue, player)
	playerQueue[player] = modeId
	broadcastQueue(modeId)
	tryStartMatch(modeId)
	return true
end

function MatchmakingManager.leaveQueue(player)
	if not playerQueue[player] then
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	sendQueueClear(player)
	broadcastQueue(modeId)
end

function MatchmakingManager.onArenaEnded()
	arenaBusy = false
	tryStartAllQueues()
end

function MatchmakingManager.isPlayerQueued(player)
	return playerQueue[player] ~= nil
end

function MatchmakingManager.init(deps)
	HubService = deps.HubService
	getActiveModeId = deps.getActiveModeId

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			modeId = getActiveModeId()
		end
		if modeId == "auto" then
			modeId = MatchmakingService.resolveAutoMode(#Players:GetPlayers())
		end
		MatchmakingManager.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)

	Bindables.MatchStarted.Event:Connect(function()
		arenaBusy = true
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingManager.onArenaEnded()
	end)

	if deps.hub and deps.hub.modePads then
		for _, pad in deps.hub.modePads do
			local modeId = pad.config.id
			local debounce = {}

			pad.part.Touched:Connect(function(hit)
				local character = hit.Parent
				if not character then
					return
				end
				local touchPlayer = Players:GetPlayerFromCharacter(character)
				if not touchPlayer or debounce[touchPlayer] then
					return
				end
				debounce[touchPlayer] = true
				task.delay(1.2, function()
					debounce[touchPlayer] = nil
				end)
				MatchmakingManager.joinQueue(touchPlayer, modeId)
			end)
		end
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)
end

return MatchmakingManager
