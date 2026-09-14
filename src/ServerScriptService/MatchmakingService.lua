local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local GameMatchState = require(ReplicatedStorage.NovaBladers.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local Remotes
local Bindables

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local ffaFillToken = 0
local ffaFillEndsAt = 0
local pendingMatch = nil
local started = false
local padDebounce = {}

local function copyPlayerList(list)
	local copy = {}
	for _, player in list do
		if player.Parent then
			table.insert(copy, player)
		end
	end
	return copy
end

local function getQueueSize(modeId)
	return #queues[modeId]
end

local function isValidMode(modeId)
	return MatchModes.get(modeId) ~= nil
end

local function removeFromQueueList(modeId, player)
	local list = queues[modeId]
	for i = #list, 1, -1 do
		if list[i] == player then
			table.remove(list, i)
		end
	end
end

local function buildQueuePayload(player)
	local modeId = playerQueue[player]
	if not modeId then
		return { inQueue = false }
	end

	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	local position = 0
	for i, queued in ipairs(list) do
		if queued == player then
			position = i
			break
		end
	end

	local payload = {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		position = position,
		queueSize = #list,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		pendingArena = pendingMatch ~= nil and GameMatchState.isBusy(),
	}

	if modeId == "ffa" and #list >= mode.minPlayers and ffaFillEndsAt > 0 then
		payload.fillSecondsLeft = math.max(0, math.ceil(ffaFillEndsAt - os.clock()))
	end

	return payload
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildQueuePayload(player))
	end
end

local function broadcastAllQueueUpdates()
	for _, player in Players:GetPlayers() do
		if playerQueue[player] then
			broadcastQueueUpdate(player)
		end
	end
end

local function cancelFfaFillTimer()
	ffaFillToken += 1
	ffaFillEndsAt = 0
end

local function shouldStartMatch(modeId)
	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	local count = #list

	if count < mode.minPlayers then
		return false
	end
	if count >= mode.maxPlayers then
		return true
	end
	if modeId == "ffa" then
		return ffaFillEndsAt > 0 and os.clock() >= ffaFillEndsAt
	end
	return count >= mode.minPlayers
end

local function takePlayersForMatch(modeId)
	local mode = MatchModes.get(modeId)
	local list = queues[modeId]
	local taken = {}
	local limit = math.min(#list, mode.maxPlayers)

	for i = 1, limit do
		local player = list[1]
		table.remove(list, 1)
		if player and player.Parent then
			table.insert(taken, player)
			playerQueue[player] = nil
		end
	end

	return taken
end

local function launchMatch(modeId, players)
	if #players == 0 then
		return
	end

	for _, player in players do
		HubService.enterArena(player)
	end

	if GameMatchState.isBusy() then
		pendingMatch = { modeId = modeId, players = players }
		for _, player in players do
			Remotes.QueueUpdate:FireClient(player, {
				inQueue = true,
				modeId = modeId,
				modeLabel = MatchModes.get(modeId).label,
				pendingArena = true,
				queueSize = #players,
				position = 1,
			})
		end
		return
	end

	Bindables.MatchReady:Fire(players)
end

local function tryStartMatch(modeId)
	if not shouldStartMatch(modeId) then
		return
	end

	cancelFfaFillTimer()
	local players = takePlayersForMatch(modeId)
	launchMatch(modeId, players)
	broadcastAllQueueUpdates()
end

local function maybeStartFfaFillTimer()
	local list = queues.ffa
	local mode = MatchModes.ffa

	if #list < mode.minPlayers then
		cancelFfaFillTimer()
		return
	end

	if #list >= mode.maxPlayers then
		tryStartMatch("ffa")
		return
	end

	if ffaFillEndsAt > 0 then
		return
	end

	ffaFillToken += 1
	local token = ffaFillToken
	ffaFillEndsAt = os.clock() + mode.fillTimeout

	task.delay(mode.fillTimeout, function()
		if token ~= ffaFillToken then
			return
		end
		if #queues.ffa >= mode.minPlayers then
			tryStartMatch("ffa")
		else
			cancelFfaFillTimer()
			broadcastAllQueueUpdates()
		end
	end)
end

local function pickQuickMode()
	local ffaSize = getQueueSize("ffa")
	local pvpSize = getQueueSize("pvp")

	if ffaSize >= MatchModes.ffa.minPlayers - 1 then
		return "ffa"
	end
	if pvpSize >= 1 then
		return "pvp"
	end

	local playerCount = #Players:GetPlayers()
	if playerCount >= 3 or ffaSize >= 2 then
		return "ffa"
	end
	if playerCount >= 2 or pvpSize >= 1 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	removeFromQueueList(modeId, player)

	if modeId == "ffa" and #queues.ffa < MatchModes.ffa.minPlayers then
		cancelFfaFillTimer()
	end

	broadcastQueueUpdate(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastAllQueueUpdates()
end

function MatchmakingService.joinQueue(player, modeId)
	if not isValidMode(modeId) then
		return
	end
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	table.insert(queues[modeId], player)
	playerQueue[player] = modeId
	broadcastQueueUpdate(player)
	broadcastAllQueueUpdates()

	if modeId == "training" or modeId == "pvp" then
		tryStartMatch(modeId)
	elseif modeId == "ffa" then
		maybeStartFfaFillTimer()
		if #queues.ffa >= MatchModes.ffa.maxPlayers then
			tryStartMatch("ffa")
		end
	end
end

function MatchmakingService.joinQuickMatch(player)
	MatchmakingService.joinQueue(player, pickQuickMode())
end

local function onArenaFree()
	if not pendingMatch then
		return
	end

	local match = pendingMatch
	pendingMatch = nil
	local players = copyPlayerList(match.players)

	if #players == 0 then
		return
	end

	for _, player in players do
		if player.Parent and HubService.getPhase(player) == "arena" then
			-- still reserved for this match
		end
	end

	Bindables.MatchReady:Fire(players)
end

local function wireModePads(hub)
	for _, pad in hub.modePads do
		local modeId = pad.config.id
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "QueuePrompt"
		prompt.ActionText = "Warteschlange"
		prompt.ObjectText = pad.config.label
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad.part

		prompt.Triggered:Connect(function(player)
			MatchmakingService.joinQueue(player, modeId)
		end)

		pad.part.Touched:Connect(function(hit)
			local character = hit.Parent
			if not character then
				return
			end
			local humanoid = character:FindFirstChildOfClass("Humanoid")
			if not humanoid then
				return
			end
			local player = Players:GetPlayerFromCharacter(character)
			if not player then
				return
			end

			local now = os.clock()
			if padDebounce[player] and now - padDebounce[player] < MatchmakingConfig.MODE_PAD_DEBOUNCE then
				return
			end
			padDebounce[player] = now
			MatchmakingService.joinQueue(player, modeId)
		end)
	end
end

function MatchmakingService.getQueueSummary()
	return {
		training = getQueueSize("training"),
		pvp = getQueueSize("pvp"),
		ffa = getQueueSize("ffa"),
	}
end

function MatchmakingService.start(hub)
	if started then
		return
	end
	started = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if modeId == "quick" or modeId == nil then
			MatchmakingService.joinQuickMatch(player)
			return
		end
		if typeof(modeId) == "string" then
			MatchmakingService.joinQueue(player, modeId)
		end
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Bindables.ArenaFree.Event:Connect(onArenaFree)

	Players.PlayerRemoving:Connect(function(player)
		padDebounce[player] = nil
		if playerQueue[player] then
			MatchmakingService.leaveQueue(player)
		end
	end)

	if hub then
		wireModePads(hub)
	end

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastAllQueueUpdates()
		end
	end)

	print("[MatchmakingService] Queue ready — Training / PvP / FFA")
end

return MatchmakingService
