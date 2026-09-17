--[[
	MatchmakingService — per-mode queues, fill timers, and MatchReady dispatch.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchModes = require(ReplicatedStorage.NovaBladers.MatchModes)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)

local MatchmakingService = {}

local queues = {}
local playerQueue = {}
local fillTokens = {}
local readyMatches = {}
local remotes
local bindables
local hubService

local function getQueue(modeId)
	if not queues[modeId] then
		queues[modeId] = {}
	end
	return queues[modeId]
end

local function removeFromQueue(player)
	local modeId = playerQueue[player]
	if not modeId then
		return
	end

	playerQueue[player] = nil
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	local mode = MatchModes.get(modeId)
	if mode and #queue < mode.minPlayers and fillTokens[modeId] then
		fillTokens[modeId] = nil
	end
end

local function buildQueuePayload(player, modeId, status)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)
	local needed = mode.maxPlayers

	if modeId == "ffa" and #queue < mode.maxPlayers then
		needed = mode.maxPlayers
	end

	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = mode.label,
		playersInQueue = #queue,
		neededPlayers = needed,
		status = status or "waiting",
	}
end

local function broadcastQueue(modeId)
	local queue = getQueue(modeId)
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent and hubService.getPhase(queuedPlayer) == "hub" then
			remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId))
		end
	end
end

local function clearQueueUI(player)
	if player.Parent then
		remotes.QueueUpdate:FireClient(player, { inQueue = false })
	end
end

local function notifyPending(players, modeId)
	for _, queuedPlayer in players do
		if queuedPlayer.Parent then
			remotes.QueueUpdate:FireClient(queuedPlayer, buildQueuePayload(queuedPlayer, modeId, "pending"))
		end
	end
end

local function takePlayersFromQueue(modeId, count)
	local queue = getQueue(modeId)
	local taken = {}

	for _ = 1, math.min(count, #queue) do
		local queuedPlayer = table.remove(queue, 1)
		if queuedPlayer and queuedPlayer.Parent then
			playerQueue[queuedPlayer] = nil
			clearQueueUI(queuedPlayer)
			table.insert(taken, queuedPlayer)
		end
	end

	fillTokens[modeId] = nil
	return taken
end

local function canStartMode(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if #queue < mode.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			return true
		end
		return fillTokens[modeId] == "expired"
	end

	return #queue >= mode.maxPlayers
end

local function launchMatch(players, modeId)
	if #players == 0 or MatchStateService.isBusy() then
		return
	end

	for _, queuedPlayer in players do
		hubService.leaveHubForArena(queuedPlayer)
	end

	bindables.MatchReady:Fire({
		players = players,
		modeId = modeId,
	})
end

local function tryStartMatch(modeId)
	if not canStartMode(modeId) then
		return
	end

	local mode = MatchModes.get(modeId)
	local players = takePlayersFromQueue(modeId, mode.maxPlayers)
	if #players < mode.minPlayers then
		for _, queuedPlayer in players do
			table.insert(getQueue(modeId), queuedPlayer)
			playerQueue[queuedPlayer] = modeId
		end
		broadcastQueue(modeId)
		return
	end

	if MatchStateService.isBusy() then
		table.insert(readyMatches, { modeId = modeId, players = players })
		notifyPending(players, modeId)
		return
	end

	launchMatch(players, modeId)
end

local function scheduleFillTimeout(modeId)
	local mode = MatchModes.get(modeId)
	local queue = getQueue(modeId)

	if modeId ~= "ffa" or #queue < mode.minPlayers or fillTokens[modeId] then
		return
	end

	local token = {}
	fillTokens[modeId] = token

	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if fillTokens[modeId] ~= token then
			return
		end

		fillTokens[modeId] = "expired"
		tryStartMatch(modeId)
	end)
end

local function processReadyMatches()
	while #readyMatches > 0 and not MatchStateService.isBusy() do
		local match = table.remove(readyMatches, 1)
		launchMatch(match.players, match.modeId)
	end
end

local function getSuggestedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

function MatchmakingService.joinQueue(player, modeId)
	if hubService.getPhase(player) ~= "hub" then
		return
	end

	if not modeId or modeId == "quick" then
		modeId = getSuggestedModeId()
	end

	if not MatchModes.isValid(modeId) then
		return
	end

	if playerQueue[player] == modeId then
		remotes.QueueUpdate:FireClient(player, buildQueuePayload(player, modeId))
		return
	end

	removeFromQueue(player)
	table.insert(getQueue(modeId), player)
	playerQueue[player] = modeId

	broadcastQueue(modeId)
	scheduleFillTimeout(modeId)
	tryStartMatch(modeId)
end

function MatchmakingService.leaveQueue(player)
	if not playerQueue[player] then
		clearQueueUI(player)
		return
	end

	local modeId = playerQueue[player]
	removeFromQueue(player)
	clearQueueUI(player)
	broadcastQueue(modeId)
end

function MatchmakingService.init(deps)
	remotes = deps.remotes
	bindables = deps.bindables
	hubService = deps.hubService

	for _, mode in MatchModes.all() do
		queues[mode.id] = {}
	end

	remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingService.joinQueue(player, modeId)
	end)

	remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		if playerQueue[player] then
			local modeId = playerQueue[player]
			removeFromQueue(player)
			broadcastQueue(modeId)
		end

		for i = #readyMatches, 1, -1 do
			local match = readyMatches[i]
			for j = #match.players, 1, -1 do
				if match.players[j] == player then
					table.remove(match.players, j)
				end
			end
			if #match.players == 0 then
				table.remove(readyMatches, i)
			end
		end
	end)

	MatchStateService.onArenaFreed(function()
		processReadyMatches()
		for _, mode in MatchModes.all() do
			tryStartMatch(mode.id)
		end
	end)
end

return MatchmakingService
