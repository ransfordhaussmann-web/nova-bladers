local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local MatchmakingService = {}

local joinHandler = nil
local hubConnections = {}
local registeredHub = nil
local recommendedModeFn = nil

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local fillTimers = {}
local arenaBusy = false

local function getQueue(modeId)
	return queues[modeId]
end

local function removeFromQueue(player, modeId)
	local queue = getQueue(modeId)
	for i, queuedPlayer in queue do
		if queuedPlayer == player then
			table.remove(queue, i)
			break
		end
	end
	if fillTimers[modeId] and #queue < (MatchmakingConfig.getMode(modeId) or {}).minPlayers then
		fillTimers[modeId] = nil
	end
end

local function clearPlayer(player)
	local modeId = playerMode[player]
	if modeId then
		removeFromQueue(player, modeId)
		playerMode[player] = nil
	end
end

function MatchmakingService.setArenaBusy(busy)
	arenaBusy = busy
end

function MatchmakingService.isArenaBusy()
	return arenaBusy
end

function MatchmakingService.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingService.getQueueSnapshot(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end

	local queue = getQueue(modeId)
	local names = {}
	for _, queuedPlayer in queue do
		if queuedPlayer.Parent then
			table.insert(names, queuedPlayer.DisplayName)
		end
	end

	return {
		modeId = modeId,
		label = mode.label,
		desc = mode.desc,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = names,
		fillTimeout = mode.fillTimeout,
		fillStartedAt = fillTimers[modeId],
	}
end

function MatchmakingService.leaveQueue(player)
	clearPlayer(player)
end

function MatchmakingService.joinQueue(player, modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	clearPlayer(player)

	local queue = getQueue(modeId)
	table.insert(queue, player)
	playerMode[player] = modeId

	if #queue >= mode.minPlayers and not fillTimers[modeId] and mode.fillTimeout > 0 then
		fillTimers[modeId] = os.clock()
	end

	return true
end

function MatchmakingService.pruneDisconnected()
	for modeId, queue in queues do
		for i = #queue, 1, -1 do
			if not queue[i].Parent then
				local removed = queue[i]
				table.remove(queue, i)
				playerMode[removed] = nil
			end
		end
		local mode = MatchmakingConfig.getMode(modeId)
		if mode and #queue < mode.minPlayers then
			fillTimers[modeId] = nil
		end
	end
end

function MatchmakingService.getReadyMatch()
	if arenaBusy then
		return nil
	end

	MatchmakingService.pruneDisconnected()

	for _, mode in MatchmakingConfig.getModeList() do
		local queue = getQueue(mode.id)
		local count = #queue
		if count < mode.minPlayers then
			continue
		end

		if count >= mode.maxPlayers then
			local players = {}
			for _ = 1, mode.maxPlayers do
				local queuedPlayer = table.remove(queue, 1)
				playerMode[queuedPlayer] = nil
				table.insert(players, queuedPlayer)
			end
			fillTimers[mode.id] = nil
			return {
				modeId = mode.id,
				players = players,
			}
		end

		if mode.fillTimeout <= 0 then
			local players = { queue[1] }
			table.remove(queue, 1)
			playerMode[players[1]] = nil
			fillTimers[mode.id] = nil
			return {
				modeId = mode.id,
				players = players,
			}
		end

		local startedAt = fillTimers[mode.id]
		if startedAt and (os.clock() - startedAt) >= mode.fillTimeout then
			local players = {}
			for i = 1, count do
				table.insert(players, queue[i])
			end
			for i = 1, count do
				table.remove(queue, 1)
			end
			for _, p in players do
				playerMode[p] = nil
			end
			fillTimers[mode.id] = nil
			return {
				modeId = mode.id,
				players = players,
			}
		end
	end

	return nil
end

function MatchmakingService.onPlayerRemoving(player)
	clearPlayer(player)
end

local function connectHubIfReady()
	if not registeredHub or not recommendedModeFn or not joinHandler then
		return
	end
	MatchmakingService.connectHub(registeredHub, recommendedModeFn)
end

function MatchmakingService.registerHub(hub, getRecommendedModeId)
	registeredHub = hub
	recommendedModeFn = getRecommendedModeId
	connectHubIfReady()
end

function MatchmakingService.setJoinHandler(handler)
	joinHandler = handler
	connectHubIfReady()
end

function MatchmakingService.connectHub(hub, getRecommendedModeId)
	for _, connection in hubConnections do
		connection:Disconnect()
	end
	table.clear(hubConnections)

	for _, pad in hub.modePads do
		local prompt = pad.part:FindFirstChild("JoinQueuePrompt")
		if prompt and joinHandler then
			table.insert(hubConnections, prompt.Triggered:Connect(function(player)
				joinHandler(player, pad.config.id)
			end))
		end
	end

	if hub.portalPrompt and joinHandler then
		table.insert(hubConnections, hub.portalPrompt.Triggered:Connect(function(player)
			joinHandler(player, getRecommendedModeId())
		end))
	end
end

return MatchmakingService
