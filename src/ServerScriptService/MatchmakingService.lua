local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local MatchReady

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerEntry = {}
local fillTokens = {}

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local queue = queues[entry.modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerEntry[player] = nil
end

local function buildQueueMessage(mode, queueSize, status)
	if status == "pending" then
		return MatchmakingConfig.PENDING_MESSAGE
	end

	if mode.id == "training" then
		return "Match startet gleich…"
	elseif mode.id == "pvp" then
		return string.format("%s (%d/%d)", MatchmakingConfig.PVP_WAIT_MESSAGE, queueSize, mode.maxPlayers)
	end

	return string.format("%s (%d/%d)", MatchmakingConfig.FFA_WAIT_MESSAGE, queueSize, mode.maxPlayers)
end

local function sendQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function broadcastQueue(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local queueSize = getQueueSize(modeId)
	local status = MatchStateService.isBusy() and "pending" or "waiting"

	for _, player in queues[modeId] do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = mode.label,
			status = status,
			queueSize = queueSize,
			requiredMin = mode.minPlayers,
			requiredMax = mode.maxPlayers,
			message = buildQueueMessage(mode, queueSize, status),
		})
	end
end

local function clearQueueUpdate(player)
	sendQueueUpdate(player, { inQueue = false })
end

local function invalidateFillTimer(modeId)
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1
end

local function scheduleFillTimer(modeId)
	local mode = MatchModes.get(modeId)
	if not mode or not mode.fillTimeout then
		return
	end

	invalidateFillTimer(modeId)
	local token = fillTokens[modeId]

	task.delay(mode.fillTimeout, function()
		if token ~= fillTokens[modeId] then
			return
		end
		MatchmakingService.tryStart(modeId, true)
	end)
end

local function takePlayers(modeId, count)
	local selected = {}
	local queue = queues[modeId]

	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerEntry[player] = nil
			table.insert(selected, player)
		end
	end

	return selected
end

function MatchmakingService.tryStart(modeId, allowPartial)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false
	end

	if MatchStateService.isBusy() then
		broadcastQueue(modeId)
		return false
	end

	local queueSize = getQueueSize(modeId)
	if queueSize < mode.minPlayers and not allowPartial then
		return false
	end

	if queueSize < mode.minPlayers then
		return false
	end

	local count = math.min(queueSize, mode.maxPlayers)
	local players = takePlayers(modeId, count)
	if #players < mode.minPlayers then
		for _, player in players do
			MatchmakingService.joinQueue(player, modeId)
		end
		return false
	end

	invalidateFillTimer(modeId)
	MatchStateService.setBusy(true)

	for _, player in players do
		sendQueueUpdate(player, {
			inQueue = true,
			modeId = modeId,
			modeLabel = mode.label,
			status = "starting",
			queueSize = #players,
			requiredMin = mode.minPlayers,
			requiredMax = mode.maxPlayers,
			message = "Match startet…",
		})
		HubService.notifyMatchStarting(player)
	end

	MatchReady:Fire(players, modeId)
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		return
	end

	if modeId == "quick" then
		modeId = MatchModes.resolveQuickMode(#Players:GetPlayers())
	end

	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if HubService.getPhase(player) == "arena" then
		return
	end

	removeFromQueue(player)

	table.insert(queues[modeId], player)
	playerEntry[player] = { modeId = modeId }

	if getQueueSize(modeId) == 1 and mode.fillTimeout then
		scheduleFillTimer(modeId)
	end

	broadcastQueue(modeId)

	if modeId == "training" then
		MatchmakingService.tryStart(modeId, false)
	elseif modeId == "pvp" and getQueueSize(modeId) >= mode.maxPlayers then
		MatchmakingService.tryStart(modeId, false)
	elseif modeId == "ffa" and getQueueSize(modeId) >= mode.maxPlayers then
		MatchmakingService.tryStart(modeId, false)
	end
end

function MatchmakingService.leaveQueue(player)
	local entry = playerEntry[player]
	if not entry then
		clearQueueUpdate(player)
		return
	end

	local modeId = entry.modeId
	removeFromQueue(player)
	clearQueueUpdate(player)

	if getQueueSize(modeId) == 0 then
		invalidateFillTimer(modeId)
	end

	broadcastQueue(modeId)
end

function MatchmakingService.onArenaFree()
	MatchStateService.setBusy(false)

	for modeId in pairs(queues) do
		if getQueueSize(modeId) > 0 then
			broadcastQueue(modeId)
			MatchmakingService.tryStart(modeId, modeId == "ffa")
		end
	end
end

function MatchmakingService.start()
	local remotes, bindables = RemotesSetup.ensure()
	Remotes = remotes
	MatchReady = bindables.MatchReady

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId or "quick")
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
