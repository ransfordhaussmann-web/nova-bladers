local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local pendingMatches = {}
local ffaFillToken = 0
local remotes = nil
local matchReadyBindable = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function removeFromQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end

	playerMode[player] = nil
end

local function buildQueuePayload(modeId, player)
	local config = getModeConfig(modeId)
	local queue = queues[modeId]
	local position = 0
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			position = i
			break
		end
	end

	return {
		mode = modeId,
		label = config.label,
		position = position,
		total = #queue,
		required = config.maxPlayers,
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = "waiting",
	}
end

local function broadcastQueueUpdate(modeId)
	local queue = queues[modeId]
	for _, player in queue do
		if player.Parent and remotes then
			remotes.QueueUpdate:FireClient(player, buildQueuePayload(modeId, player))
		end
	end
end

local function broadcastPending(players, modeId)
	local config = getModeConfig(modeId)
	for _, player in players do
		if player.Parent and remotes then
			remotes.QueueUpdate:FireClient(player, {
				mode = modeId,
				label = config.label,
				position = 0,
				total = #players,
				required = config.maxPlayers,
				minPlayers = config.minPlayers,
				maxPlayers = config.maxPlayers,
				status = "pending",
			})
		end
	end
end

local function setPlayerQueued(player)
	if HubService.setPhase then
		HubService.setPhase(player, "queued")
	end
end

local function clearPlayerQueueState(player)
	if HubService.setPhase then
		HubService.setPhase(player, "hub")
	end
end

function MatchmakingService.init(remotesFolder, bindablesFolder)
	remotes = remotesFolder
	matchReadyBindable = bindablesFolder.MatchReady
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.isQueued(player)
	return playerMode[player] ~= nil
end

function MatchmakingService.leaveQueue(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	removeFromQueue(player)
	clearPlayerQueueState(player)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" or not getModeConfig(modeId) then
		return false
	end

	if HubService.getPhase(player) == "arena" then
		return false
	end

	if MatchStateService.isArenaBusy() and playerMode[player] == modeId then
		return false
	end

	removeFromQueue(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	setPlayerQueued(player)
	broadcastQueueUpdate(modeId)
	MatchmakingService.tryStartMode(modeId)
	return true
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(taken, player)
		end
	end
	return taken
end

local function startMatch(players, modeId)
	for _, player in players do
		if HubService.setPhase then
			HubService.setPhase(player, "arena")
		end
	end

	MatchStateService.setArenaBusy(true)

	if matchReadyBindable then
		matchReadyBindable:Fire(players, modeId)
	end
end

function MatchmakingService.tryStartMode(modeId)
	local config = getModeConfig(modeId)
	if not config then
		return
	end

	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return
	end

	if modeId == "ffa" then
		if #queue >= config.maxPlayers then
			ffaFillToken += 1
		elseif #queue >= config.minPlayers then
			ffaFillToken += 1
			local token = ffaFillToken
			task.delay(config.fillTimeout, function()
				if token ~= ffaFillToken then
					return
				end
				if #queues.ffa < config.minPlayers then
					return
				end
				MatchmakingService.tryStartMode("ffa")
			end)
			return
		else
			return
		end
	end

	local playerCount = math.min(#queue, config.maxPlayers)
	local players = takePlayersFromQueue(modeId, playerCount)
	if #players < config.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		broadcastQueueUpdate(modeId)
		return
	end

	if MatchStateService.isArenaBusy() then
		table.insert(pendingMatches, { players = players, modeId = modeId })
		broadcastPending(players, modeId)
		return
	end

	startMatch(players, modeId)
	broadcastQueueUpdate(modeId)
end

function MatchmakingService.onMatchEnded()
	MatchStateService.setArenaBusy(false)
	MatchStateService.notifyArenaFree()

	while #pendingMatches > 0 and not MatchStateService.isArenaBusy() do
		local nextMatch = table.remove(pendingMatches, 1)
		local validPlayers = {}
		for _, player in nextMatch.players do
			if player.Parent then
				table.insert(validPlayers, player)
			end
		end

		local config = getModeConfig(nextMatch.modeId)
		if config and #validPlayers >= config.minPlayers then
			startMatch(validPlayers, nextMatch.modeId)
		else
			for _, player in validPlayers do
				MatchmakingService.joinQueue(player, nextMatch.modeId)
			end
		end
	end

	for modeId in MatchmakingConfig.MODES do
		MatchmakingService.tryStartMode(modeId)
	end
end

function MatchmakingService.onPlayerRemoving(player)
	removeFromQueue(player)
	playerMode[player] = nil

	for i = #pendingMatches, 1, -1 do
		local match = pendingMatches[i]
		for j, pendingPlayer in match.players do
			if pendingPlayer == player then
				table.remove(match.players, j)
				break
			end
		end
		if #match.players == 0 then
			table.remove(pendingMatches, i)
		end
	end
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

return MatchmakingService
