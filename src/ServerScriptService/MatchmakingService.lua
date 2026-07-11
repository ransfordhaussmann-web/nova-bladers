local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes = RemotesSetup.ensure()

local MatchmakingService = {}

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerQueue = {}
local matchInProgress = false
local onMatchFormedCallback = nil

local function getModeConfig(modeId)
	return MatchmakingConfig.MODES[modeId]
end

local function isValidMode(modeId)
	return getModeConfig(modeId) ~= nil
end

local function removeFromQueueList(queue, player)
	for i, entry in queue do
		if entry.player == player then
			table.remove(queue, i)
			return true
		end
	end
	return false
end

local function buildQueueSnapshot()
	local snapshot = {}
	for modeId, queue in queues do
		snapshot[modeId] = #queue
	end
	return snapshot
end

local function broadcastQueueState()
	local snapshot = buildQueueSnapshot()
	for _, player in Players:GetPlayers() do
		local info = playerQueue[player]
		Remotes.QueueState:FireClient(player, {
			counts = snapshot,
			queued = info ~= nil,
			mode = info and info.mode,
			position = info and info.position,
			playersNeeded = info and info.playersNeeded,
		})
	end
end

local function setPlayerQueueInfo(player, modeId)
	local queue = queues[modeId]
	local position = 0
	for i, entry in queue do
		if entry.player == player then
			position = i
			break
		end
	end

	local modeCfg = getModeConfig(modeId)
	playerQueue[player] = {
		mode = modeId,
		position = position,
		playersNeeded = math.max(0, modeCfg.minPlayers - #queue),
		joinedAt = os.clock(),
	}
end

function MatchmakingService.leaveQueue(player)
	local info = playerQueue[player]
	if not info then
		return false
	end

	removeFromQueueList(queues[info.mode], player)
	playerQueue[player] = nil
	broadcastQueueState()
	MatchmakingService.tryFormMatches()
	return true
end

function MatchmakingService.joinQueue(player, modeId)
	if matchInProgress then
		return false, "match_in_progress"
	end
	if not isValidMode(modeId) then
		return false, "invalid_mode"
	end
	if playerQueue[player] then
		MatchmakingService.leaveQueue(player)
	end

	local modeCfg = getModeConfig(modeId)
	local queue = queues[modeId]
	if #queue >= modeCfg.maxPlayers then
		return false, "queue_full"
	end

	table.insert(queue, {
		player = player,
		joinedAt = os.clock(),
	})
	setPlayerQueueInfo(player, modeId)
	broadcastQueueState()
	MatchmakingService.tryFormMatches()
	return true
end

function MatchmakingService.getPlayerQueue(player)
	return playerQueue[player]
end

function MatchmakingService.getQueueCounts()
	return buildQueueSnapshot()
end

function MatchmakingService.setMatchInProgress(active)
	matchInProgress = active
	if not active then
		MatchmakingService.tryFormMatches()
	end
end

function MatchmakingService.onMatchFormed(callback)
	onMatchFormedCallback = callback
end

local function takePlayersFromQueue(modeId, count)
	local queue = queues[modeId]
	local taken = {}
	for _ = 1, math.min(count, #queue) do
		local entry = table.remove(queue, 1)
		if entry and entry.player.Parent then
			table.insert(taken, entry.player)
			playerQueue[entry.player] = nil
		end
	end
	return taken
end

local function formMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	matchInProgress = true
	broadcastQueueState()

	if onMatchFormedCallback then
		onMatchFormedCallback(playerList, modeId)
	end
end

function MatchmakingService.tryFormMatches()
	if matchInProgress then
		return
	end

	local trainingCfg = getModeConfig("training")
	while #queues.training >= trainingCfg.minPlayers do
		local players = takePlayersFromQueue("training", trainingCfg.maxPlayers)
		if #players > 0 then
			formMatch("training", players)
			return
		end
	end

	local pvpCfg = getModeConfig("pvp")
	while #queues.pvp >= pvpCfg.minPlayers do
		local players = takePlayersFromQueue("pvp", pvpCfg.maxPlayers)
		if #players > 0 then
			formMatch("pvp", players)
			return
		end
	end

	local ffaCfg = getModeConfig("ffa")
	if #queues.ffa >= ffaCfg.minPlayers then
		local count = math.min(#queues.ffa, ffaCfg.maxPlayers)
		local players = takePlayersFromQueue("ffa", count)
		if #players > 0 then
			formMatch("ffa", players)
			return
		end
	end

	local now = os.clock()
	if #queues.ffa >= 2 then
		local oldest = queues.ffa[1]
		if oldest and (now - oldest.joinedAt) >= ffaCfg.twoPlayerTimeout then
			local players = takePlayersFromQueue("ffa", math.min(#queues.ffa, ffaCfg.maxPlayers))
			if #players >= 2 then
				formMatch("ffa", players)
			end
		end
	end
end

function MatchmakingService.init()
	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.TICK_INTERVAL)
			MatchmakingService.tryFormMatches()
			if next(playerQueue) then
				broadcastQueueState()
			end
		end
	end)
end

return MatchmakingService
