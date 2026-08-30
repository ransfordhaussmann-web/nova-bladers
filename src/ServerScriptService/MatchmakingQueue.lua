local Players = game:GetService("Players")

local MatchmakingConfig = require(game:GetService("ReplicatedStorage").NovaBladers.MatchmakingConfig)

local MatchmakingQueue = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local modeState = {}
local remotes = nil
local onMatchReady = nil

for _, modeId in MatchmakingConfig.QUEUE_ORDER do
	modeState[modeId] = {
		countdown = nil,
		token = 0,
	}
end

local function getConfig(modeId)
	return MatchmakingConfig.QUEUES[modeId]
end

local function isValidMode(modeId)
	return getConfig(modeId) ~= nil
end

local function playerInList(list, player)
	for index, queuedPlayer in list do
		if queuedPlayer == player then
			return index
		end
	end
	return nil
end

local function pruneQueue(modeId)
	local list = queues[modeId]
	local writeIndex = 1
	for readIndex = 1, #list do
		local queuedPlayer = list[readIndex]
		if queuedPlayer.Parent then
			list[writeIndex] = queuedPlayer
			writeIndex += 1
		else
			playerMode[queuedPlayer] = nil
		end
	end
	for index = writeIndex, #list do
		list[index] = nil
	end
end

local function buildPayload(modeId, player)
	local config = getConfig(modeId)
	pruneQueue(modeId)
	local list = queues[modeId]
	local names = {}
	for _, queuedPlayer in list do
		table.insert(names, queuedPlayer.DisplayName)
	end

	return {
		modeId = modeId,
		modeLabel = config.label,
		players = #list,
		needed = config.minPlayers,
		maxPlayers = config.maxPlayers,
		playerNames = names,
		inQueue = player ~= nil and playerInList(list, player) ~= nil,
		countdown = modeState[modeId].countdown,
	}
end

local function fireQueueUpdate(modeId)
	if not remotes then
		return
	end
	pruneQueue(modeId)
	for _, player in queues[modeId] do
		if player.Parent then
			remotes.QueueUpdate:FireClient(player, buildPayload(modeId, player))
		end
	end
end

local function cancelCountdown(modeId)
	local state = modeState[modeId]
	state.token += 1
	state.countdown = nil
end

local function pullPlayersForMatch(modeId)
	pruneQueue(modeId)
	local config = getConfig(modeId)
	local list = queues[modeId]
	local matchPlayers = {}
	local takeCount = math.min(#list, config.maxPlayers)

	for index = 1, takeCount do
		local player = list[index]
		if player.Parent then
			table.insert(matchPlayers, player)
		end
		playerMode[player] = nil
	end

	queues[modeId] = {}
	cancelCountdown(modeId)
	return matchPlayers
end

local function startMatch(modeId)
	local matchPlayers = pullPlayersForMatch(modeId)
	if #matchPlayers == 0 then
		return
	end

	if onMatchReady then
		onMatchReady(matchPlayers, modeId)
	end
end

local function shouldStartCountdown(modeId)
	local config = getConfig(modeId)
	pruneQueue(modeId)
	return #queues[modeId] >= config.minPlayers
end

local function beginCountdown(modeId)
	local config = getConfig(modeId)
	local state = modeState[modeId]
	state.token += 1
	local token = state.token

	for seconds = config.startDelay, 1, -1 do
		if token ~= state.token then
			return
		end
		if not shouldStartCountdown(modeId) then
			state.countdown = nil
			fireQueueUpdate(modeId)
			return
		end

		state.countdown = seconds
		fireQueueUpdate(modeId)
		task.wait(1)
	end

	if token ~= state.token then
		return
	end
	if not shouldStartCountdown(modeId) then
		state.countdown = nil
		fireQueueUpdate(modeId)
		return
	end

	state.countdown = nil
	startMatch(modeId)
end

local function tryScheduleStart(modeId)
	local config = getConfig(modeId)
	pruneQueue(modeId)

	if #queues[modeId] < config.minPlayers then
		cancelCountdown(modeId)
		fireQueueUpdate(modeId)
		return
	end

	if modeState[modeId].countdown ~= nil then
		fireQueueUpdate(modeId)
		return
	end

	task.spawn(beginCountdown, modeId)
end

function MatchmakingQueue.init(remotesFolder, matchReadyCallback)
	remotes = remotesFolder
	onMatchReady = matchReadyCallback
end

function MatchmakingQueue.join(player, modeId)
	if not isValidMode(modeId) or not player.Parent then
		return false
	end

	MatchmakingQueue.leave(player)

	pruneQueue(modeId)
	local config = getConfig(modeId)
	if #queues[modeId] >= config.maxPlayers then
		return false
	end

	table.insert(queues[modeId], player)
	playerMode[player] = modeId
	fireQueueUpdate(modeId)
	tryScheduleStart(modeId)
	return true
end

function MatchmakingQueue.leave(player)
	local modeId = playerMode[player]
	if not modeId then
		return false
	end

	local index = playerInList(queues[modeId], player)
	if index then
		table.remove(queues[modeId], index)
	end
	playerMode[player] = nil

	cancelCountdown(modeId)
	fireQueueUpdate(modeId)
	tryScheduleStart(modeId)
	return true
end

function MatchmakingQueue.getPlayerMode(player)
	return playerMode[player]
end

function MatchmakingQueue.getQueueSnapshot(modeId, player)
	if not isValidMode(modeId) then
		return nil
	end
	return buildPayload(modeId, player)
end

function MatchmakingQueue.clearPlayer(player)
	MatchmakingQueue.leave(player)
end

Players.PlayerRemoving:Connect(function(player)
	MatchmakingQueue.clearPlayer(player)
end)

return MatchmakingQueue
