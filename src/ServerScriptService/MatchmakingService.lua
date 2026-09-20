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
local MatchEnded

local queues = {}
local playerEntries = {}
local padTouchCooldown = {}
local fillTokens = {}
local fillScheduled = {}

local function ensureQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function getQueueSize(modeId)
	return #ensureQueue(modeId)
end

local function isPlayerInQueue(player)
	return playerEntries[player] ~= nil
end

local function buildStatusMessage(mode, entry, queueSize)
	if entry.status == "pending" then
		return "Arena belegt — du bist als Nächstes dran"
	end

	if mode.id == "training" then
		return "Match startet gleich…"
	end

	if mode.id == "pvp" then
		return string.format("Warte auf Gegner… (%d/2)", queueSize)
	end

	return string.format("Warte auf Spieler… (%d–%d)", mode.minPlayers, mode.maxPlayers)
end

local function sendQueueUpdate(player)
	local entry = playerEntries[player]
	if not entry then
		Remotes.QueueUpdate:FireClient(player, { inQueue = false })
		return
	end

	local mode = MatchModes.get(entry.modeId)
	local queueSize = getQueueSize(entry.modeId)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = true,
		modeId = entry.modeId,
		status = entry.status,
		queueSize = queueSize,
		modeLabel = mode and mode.label or entry.modeId,
		message = mode and buildStatusMessage(mode, entry, queueSize) or "In Warteschlange…",
	})
end

local function broadcastQueueUpdates(modeId)
	for player, entry in playerEntries do
		if entry.modeId == modeId and player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function refreshPendingStatus()
	local busy = MatchStateService.isBusy()
	for player, entry in playerEntries do
		entry.status = busy and "pending" or "waiting"
		if player.Parent then
			sendQueueUpdate(player)
		end
	end
end

local function removeFromQueue(player, silent)
	local entry = playerEntries[player]
	if not entry then
		return
	end

	local queue = ensureQueue(entry.modeId)
	for index, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, index)
			break
		end
	end

	playerEntries[player] = nil
	fillTokens[entry.modeId] = (fillTokens[entry.modeId] or 0) + 1
	fillScheduled[entry.modeId] = nil

	if not silent then
		sendQueueUpdate(player)
		broadcastQueueUpdates(entry.modeId)
	end
end

local function addToQueue(player, modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return false, "Unbekannter Modus"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "Nur aus der Lobby möglich"
	end

	if isPlayerInQueue(player) then
		removeFromQueue(player, true)
	end

	local queue = ensureQueue(modeId)
	table.insert(queue, player)
	playerEntries[player] = {
		modeId = modeId,
		status = MatchStateService.isBusy() and "pending" or "waiting",
	}

	sendQueueUpdate(player)
	broadcastQueueUpdates(modeId)
	return true
end

local function takePlayersFromQueue(modeId, count)
	local queue = ensureQueue(modeId)
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerEntries[player] = nil
		end
	end
	broadcastQueueUpdates(modeId)
	return taken
end

local function launchMatch(modeId, matchPlayers)
	if #matchPlayers == 0 then
		return
	end

	fillScheduled[modeId] = nil
	fillTokens[modeId] = (fillTokens[modeId] or 0) + 1

	for _, player in matchPlayers do
		HubService.leaveHubForArena(player)
	end

	MatchReady:Fire({
		modeId = modeId,
		players = matchPlayers,
	})
end

local function tryStartMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	if MatchStateService.isBusy() then
		refreshPendingStatus()
		return
	end

	local queue = ensureQueue(modeId)
	if #queue < mode.minPlayers then
		return
	end

	if mode.fillTimeout <= 0 then
		local count = math.min(#queue, mode.maxPlayers)
		local matchPlayers = takePlayersFromQueue(modeId, count)
		launchMatch(modeId, matchPlayers)
		return
	end

	if fillScheduled[modeId] then
		return
	end

	fillScheduled[modeId] = true
	local token = (fillTokens[modeId] or 0) + 1
	fillTokens[modeId] = token

	task.delay(mode.fillTimeout, function()
		fillScheduled[modeId] = nil
		if fillTokens[modeId] ~= token or MatchStateService.isBusy() then
			return
		end

		local currentQueue = ensureQueue(modeId)
		if #currentQueue < mode.minPlayers then
			return
		end

		local count = math.min(#currentQueue, mode.maxPlayers)
		local matchPlayers = takePlayersFromQueue(modeId, count)
		launchMatch(modeId, matchPlayers)
	end)
end

local function tryStartAllModes()
	for _, mode in MatchModes.all() do
		tryStartMode(mode.id)
	end
end

local function joinQueue(player, modeId)
	local ok, err = addToQueue(player, modeId)
	if ok then
		tryStartMode(modeId)
	end
	return ok, err
end

local function leaveQueue(player)
	if not isPlayerInQueue(player) then
		return
	end
	removeFromQueue(player)
end

local function onMatchEnded()
	MatchStateService.setBusy(false)
	task.defer(tryStartAllModes)
end

local function bindModePad(pad)
	local modeId = pad.config.id
	pad.part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end

		local now = os.clock()
		if padTouchCooldown[player] and now - padTouchCooldown[player] < MatchmakingConfig.PAD_TOUCH_COOLDOWN then
			return
		end
		padTouchCooldown[player] = now

		joinQueue(player, modeId)
	end)
end

function MatchmakingService.init(hub)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		leaveQueue(player)
	end)

	MatchEnded.Event:Connect(onMatchEnded)

	for _, pad in hub.modePads do
		bindModePad(pad)
	end

	Players.PlayerRemoving:Connect(function(player)
		padTouchCooldown[player] = nil
		if isPlayerInQueue(player) then
			removeFromQueue(player, true)
		end
	end)

	print("[MatchmakingService] Queue ready — Mode-Pads, Portal & Schnell-Match")
end

function MatchmakingService.joinQueue(player, modeId)
	return joinQueue(player, modeId)
end

function MatchmakingService.leaveQueue(player)
	leaveQueue(player)
end

function MatchmakingService.isInQueue(player)
	return isPlayerInQueue(player)
end

return MatchmakingService
