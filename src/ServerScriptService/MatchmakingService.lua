local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local Remotes, Bindables
local callbacks = {}

local queues = {}
local playerQueue = {}
local ffaFillToken = {}
local matchStarting = false

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function buildQueuePayload(player)
	local info = playerQueue[player]
	if not info then
		return nil
	end

	local mode = MatchModes.get(info.modeId)
	local queue = getQueue(info.modeId)
	return {
		modeId = info.modeId,
		modeLabel = mode and mode.label or info.modeId,
		status = info.status,
		count = #queue,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
	}
end

local function sendQueueUpdate(player)
	local payload = buildQueuePayload(player)
	if payload then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	for _, player in getQueue(modeId) do
		sendQueueUpdate(player)
	end
end

local function cancelFfaFill(modeId)
	ffaFillToken[modeId] = (ffaFillToken[modeId] or 0) + 1
end

local function removeFromQueue(player)
	local info = playerQueue[player]
	if not info then
		return
	end

	local queue = getQueue(info.modeId)
	local index = table.find(queue, player)
	if index then
		table.remove(queue, index)
	end

	playerQueue[player] = nil
	sendQueueUpdate(player)
	broadcastQueue(info.modeId)

	local mode = MatchModes.get(info.modeId)
	if mode and #queue < mode.minPlayers then
		cancelFfaFill(info.modeId)
	end
end

local function markQueuePending(modeId)
	for _, player in getQueue(modeId) do
		local info = playerQueue[player]
		if info and info.status ~= "pending" then
			info.status = "pending"
			sendQueueUpdate(player)
		end
	end
end

local function takeMatchPlayers(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	if not mode or #queue < mode.minPlayers then
		return nil
	end

	local takeCount = math.min(#queue, mode.maxPlayers)
	local matchPlayers = {}
	for _ = 1, takeCount do
		table.insert(matchPlayers, table.remove(queue, 1))
	end

	cancelFfaFill(modeId)
	return matchPlayers
end

local function tryStartMatch(modeId, force)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queue = getQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if modeId == "ffa" and not force then
		if #queue >= mode.maxPlayers then
			force = true
		else
			if not ffaFillToken[modeId .. "_active"] then
				ffaFillToken[modeId .. "_active"] = true
				local token = (ffaFillToken[modeId] or 0) + 1
				ffaFillToken[modeId] = token
				task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
					if ffaFillToken[modeId] ~= token then
						return
					end
					ffaFillToken[modeId .. "_active"] = nil
					tryStartMatch(modeId, true)
				end)
			end
			return
		end
	end

	if MatchStateService.isBusy() or matchStarting then
		markQueuePending(modeId)
		return
	end

	matchStarting = true
	local matchPlayers = takeMatchPlayers(modeId)
	if not matchPlayers or #matchPlayers == 0 then
		matchStarting = false
		return
	end

	for _, player in matchPlayers do
		playerQueue[player] = nil
		if callbacks.leaveHubForArena then
			callbacks.leaveHubForArena(player)
		end
	end

	broadcastQueue(modeId)
	Bindables.MatchReady:Fire(matchPlayers)
	matchStarting = false
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		return
	end
	removeFromQueue(player)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if callbacks.getPhase and callbacks.getPhase(player) ~= "hub" then
		return
	end

	MatchmakingService.leaveQueue(player)

	local queue = getQueue(modeId)
	if #queue >= MatchmakingConfig.MAX_QUEUE_SIZE then
		return
	end

	table.insert(queue, player)
	playerQueue[player] = {
		modeId = modeId,
		status = MatchStateService.isBusy() and "pending" or "waiting",
	}

	sendQueueUpdate(player)
	broadcastQueue(modeId)
	tryStartMatch(modeId, false)
end

function MatchmakingService.onArenaIdle()
	for modeId in pairs(queues) do
		if typeof(modeId) == "string" then
			for _, player in getQueue(modeId) do
				local info = playerQueue[player]
				if info and info.status == "pending" then
					info.status = "waiting"
					sendQueueUpdate(player)
				end
			end
			tryStartMatch(modeId, modeId == "ffa")
		end
	end
end

function MatchmakingService.start(handlers)
	callbacks = handlers or {}
	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	MatchStateService.onIdle(function()
		MatchmakingService.onArenaIdle()
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
