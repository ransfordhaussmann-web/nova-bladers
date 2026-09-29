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
local MatchEnded

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaFillToken = 0
local ffaFillModeId = nil

local function getQueue(modeId)
	return queues[modeId]
end

local function modeFromPlayerCount(count)
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function queueIndex(modeId, player)
	local q = getQueue(modeId)
	for i, p in q do
		if p == player then
			return i
		end
	end
	return nil
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local q = getQueue(modeId)
	local idx = queueIndex(modeId, player)
	return {
		modeId = modeId,
		modeLabel = mode and mode.label or modeId,
		position = idx,
		queueSize = #q,
		minPlayers = mode and mode.minPlayers or 1,
		maxPlayers = mode and mode.maxPlayers or 1,
		status = status or "waiting",
		arenaBusy = MatchStateService.isArenaBusy(),
	}
end

local function sendQueueUpdate(player, modeId, status)
	if not player.Parent then
		return
	end
	Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId, status))
end

local function broadcastQueueUpdates(modeId)
	for _, player in getQueue(modeId) do
		local status = "waiting"
		if MatchStateService.isArenaBusy() then
			local mode = MatchModes.get(modeId)
			if mode and #getQueue(modeId) >= mode.minPlayers then
				status = "pending"
			end
		end
		sendQueueUpdate(player, modeId, status)
	end
end

local function clearPlayerFromQueues(player)
	local prev = playerMode[player]
	playerMode[player] = nil
	if not prev then
		return
	end
	local q = getQueue(prev)
	for i = #q, 1, -1 do
		if q[i] == player then
			table.remove(q, i)
		end
	end
	broadcastQueueUpdates(prev)
end

function MatchmakingService.leaveQueue(player)
	if not playerMode[player] then
		return
	end
	clearPlayerFromQueues(player)
	Remotes.QueueUpdate:FireClient(player, { status = "idle" })
end

local function markPlayersArena(players)
	for _, player in players do
		if HubService.getPhase(player) ~= "arena" then
			HubService.enterArena(player)
		end
	end
end

local function popPlayersForMatch(modeId, count)
	local q = getQueue(modeId)
	local picked = {}
	for _ = 1, math.min(count, #q) do
		local player = table.remove(q, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(picked, player)
		end
	end
	return picked
end

local function tryStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local q = getQueue(modeId)
	if #q < mode.minPlayers then
		return
	end

	if MatchStateService.isArenaBusy() then
		broadcastQueueUpdates(modeId)
		return
	end

	local count = math.min(#q, mode.maxPlayers)
	local players = popPlayersForMatch(modeId, count)
	if #players < mode.minPlayers then
		for _, player in players do
			table.insert(q, player)
			playerMode[player] = modeId
		end
		return
	end

	for _, player in players do
		sendQueueUpdate(player, modeId, "starting")
	end

	MatchStateService.setArenaBusy(true)
	markPlayersArena(players)
	MatchReady:Fire({
		players = players,
		mode = modeId,
	})

	broadcastQueueUpdates(modeId)
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
	ffaFillModeId = nil
end

local function scheduleFfaFill(modeId)
	if ffaFillModeId == modeId then
		return
	end
	cancelFfaFillTimer()
	ffaFillModeId = modeId
	local token = ffaFillToken
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaFillToken or ffaFillModeId ~= modeId then
			return
		end
		ffaFillModeId = nil
		tryStartMatch(modeId)
	end)
end

local function evaluateMode(modeId)
	local mode = MatchModes.get(modeId)
	if not mode then
		return
	end

	local q = getQueue(modeId)
	if #q >= mode.maxPlayers then
		cancelFfaFillTimer()
		tryStartMatch(modeId)
		return
	end

	if modeId == "ffa" and #q >= mode.minPlayers then
		scheduleFfaFill(modeId)
	elseif #q >= mode.minPlayers then
		tryStartMatch(modeId)
	end
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not MatchModes.get(modeId) then
		return
	end
	if HubService.getPhase(player) == "arena" then
		return
	end

	clearPlayerFromQueues(player)
	playerMode[player] = modeId
	table.insert(getQueue(modeId), player)
	sendQueueUpdate(player, modeId, "waiting")
	evaluateMode(modeId)
end

function MatchmakingService.joinSuggestedQueue(player)
	MatchmakingService.joinQueue(player, modeFromPlayerCount(#Players:GetPlayers()))
end

function MatchmakingService.getPlayerQueueMode(player)
	return playerMode[player]
end

function MatchmakingService.onMatchEnded()
	cancelFfaFillTimer()
	for modeId in pairs(queues) do
		evaluateMode(modeId)
	end
end

function MatchmakingService.init(hub)
	Remotes, Bindables = RemotesSetup.ensure()
	MatchReady = Bindables.MatchReady
	MatchEnded = Bindables.MatchEnded

	MatchEnded.Event:Connect(function()
		MatchmakingService.onMatchEnded()
	end)

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == nil or modeId == "suggested" then
			MatchmakingService.joinSuggestedQueue(player)
		else
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	if hub and hub.modePads then
		for _, pad in hub.modePads do
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "QueuePrompt"
			prompt.ActionText = MatchmakingConfig.MODE_PAD_PROMPT_ACTION
			prompt.ObjectText = pad.config.label
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = pad.part

			local modeId = pad.config.id
			prompt.Triggered:Connect(function(triggerPlayer)
				MatchmakingService.joinQueue(triggerPlayer, modeId)
			end)
		end
	end

	if hub and hub.portalPrompt then
		hub.portalPrompt.ActionText = MatchmakingConfig.PORTAL_PROMPT_ACTION
		hub.portalPrompt.ObjectText = "Nova Arena"
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	print("[MatchmakingService] Queue ready")
end

return MatchmakingService
