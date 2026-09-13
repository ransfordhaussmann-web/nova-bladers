local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local GameMatchState = require(script.Parent.GameMatchState)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()
local MatchReady = Bindables.MatchReady
local ArenaFree = Bindables.ArenaFree

local queues = {
	training = {},
	pvp = {},
	ffa = {},
}

local playerMode = {}
local ffaTimerToken = 0
local pendingMatch = nil
local callbacks = {}

local MatchmakingService = {}

local function playerInList(list, player)
	for _, p in list do
		if p == player then
			return true
		end
	end
	return false
end

local function removeFromAllQueues(player)
	local modeId = playerMode[player]
	if not modeId then
		return
	end

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end
	playerMode[player] = nil
end

local function getQueuePosition(modeId, player)
	for i, p in queues[modeId] do
		if p == player then
			return i
		end
	end
	return nil
end

local function buildQueueUpdate(player)
	local modeId = playerMode[player]
	if pendingMatch and playerInList(pendingMatch.players, player) then
		local config = MatchmakingConfig.MODES[pendingMatch.modeId]
		return {
			inQueue = true,
			modeId = pendingMatch.modeId,
			modeLabel = config.label,
			queueSize = #pendingMatch.players,
			minPlayers = config.minPlayers,
			maxPlayers = config.maxPlayers,
			status = if GameMatchState.isArenaBusy() then "pending" else "starting",
			arenaBusy = GameMatchState.isArenaBusy(),
		}
	end

	if not modeId then
		return { inQueue = false }
	end

	local config = MatchmakingConfig.MODES[modeId]
	return {
		inQueue = true,
		modeId = modeId,
		modeLabel = config.label,
		position = getQueuePosition(modeId, player),
		queueSize = #queues[modeId],
		minPlayers = config.minPlayers,
		maxPlayers = config.maxPlayers,
		status = "waiting",
		arenaBusy = GameMatchState.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(targetPlayer)
	if targetPlayer then
		Remotes.QueueUpdate:FireClient(targetPlayer, buildQueueUpdate(targetPlayer))
		return
	end

	for _, player in Players:GetPlayers() do
		if playerMode[player] or (pendingMatch and playerInList(pendingMatch.players, player)) then
			Remotes.QueueUpdate:FireClient(player, buildQueueUpdate(player))
		end
	end
end

local function filterValidPlayers(playerList)
	local valid = {}
	for _, player in playerList do
		if player.Parent then
			table.insert(valid, player)
		end
	end
	return valid
end

local function pullFromQueue(modeId, count)
	local pulled = {}
	for _ = 1, count do
		local player = table.remove(queues[modeId], 1)
		if player and player.Parent then
			playerMode[player] = nil
			table.insert(pulled, player)
		end
	end
	return pulled
end

local function reservePlayers(modeId)
	local config = MatchmakingConfig.MODES[modeId]
	local queue = queues[modeId]
	if #queue < config.minPlayers then
		return nil
	end

	local count = math.min(#queue, config.maxPlayers)
	if modeId == "training" then
		count = 1
	elseif modeId == "pvp" then
		count = 2
	end

	local players = pullFromQueue(modeId, count)
	if #players < config.minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		return nil
	end

	return players
end

local function launchMatch(modeId, players)
	players = filterValidPlayers(players)
	local config = MatchmakingConfig.MODES[modeId]
	if #players < config.minPlayers then
		return false
	end

	pendingMatch = nil
	GameMatchState.setArenaBusy(true)

	if callbacks.onMatchStarting then
		callbacks.onMatchStarting(players)
	end

	MatchReady:Fire(modeId, players)

	for _, player in players do
		Remotes.QueueUpdate:FireClient(player, {
			inQueue = false,
			status = "starting",
			modeId = modeId,
			modeLabel = config.label,
		})
	end

	return true
end

local function tryReserveMatch(modeId)
	if pendingMatch or GameMatchState.isArenaBusy() then
		return
	end

	local players = reservePlayers(modeId)
	if not players then
		return
	end

	if GameMatchState.isArenaBusy() then
		pendingMatch = { modeId = modeId, players = players }
		broadcastQueueUpdate()
		return
	end

	launchMatch(modeId, players)
end

local function tryLaunchPending()
	if not pendingMatch or GameMatchState.isArenaBusy() then
		return
	end

	local modeId = pendingMatch.modeId
	local players = filterValidPlayers(pendingMatch.players)
	pendingMatch = nil

	if #players < MatchmakingConfig.MODES[modeId].minPlayers then
		for _, player in players do
			table.insert(queues[modeId], player)
			playerMode[player] = modeId
		end
		broadcastQueueUpdate()
		return
	end

	launchMatch(modeId, players)
end

local function tryAllQueues()
	if GameMatchState.isArenaBusy() then
		return
	end

	if pendingMatch then
		tryLaunchPending()
		return
	end

	tryReserveMatch("training")
	if not GameMatchState.isArenaBusy() and not pendingMatch then
		tryReserveMatch("pvp")
	end
	if not GameMatchState.isArenaBusy() and not pendingMatch then
		tryReserveMatch("ffa")
	end
end

local function cancelFfaTimer()
	ffaTimerToken += 1
end

local function scheduleFfaLaunch()
	cancelFfaTimer()
	local token = ffaTimerToken
	task.delay(MatchmakingConfig.FFA_FILL_TIMEOUT, function()
		if token ~= ffaTimerToken then
			return
		end
		if pendingMatch or GameMatchState.isArenaBusy() then
			local players = reservePlayers("ffa")
			if players then
				pendingMatch = { modeId = "ffa", players = players }
				broadcastQueueUpdate()
			end
			return
		end
		tryReserveMatch("ffa")
	end)
end

local function onFfaQueueChanged()
	local config = MatchmakingConfig.MODES.ffa
	local queue = queues.ffa

	if #queue >= config.maxPlayers then
		cancelFfaTimer()
		if GameMatchState.isArenaBusy() then
			local players = reservePlayers("ffa")
			if players then
				pendingMatch = { modeId = "ffa", players = players }
				broadcastQueueUpdate()
			end
		else
			tryReserveMatch("ffa")
		end
		return
	end

	if #queue >= config.minPlayers then
		scheduleFfaLaunch()
	else
		cancelFfaTimer()
	end
end

local function evaluateMode(modeId)
	if modeId == "ffa" then
		onFfaQueueChanged()
		return
	end

	local config = MatchmakingConfig.MODES[modeId]
	if #queues[modeId] < config.minPlayers then
		return
	end

	if GameMatchState.isArenaBusy() then
		local players = reservePlayers(modeId)
		if players then
			pendingMatch = { modeId = modeId, players = players }
			broadcastQueueUpdate()
		end
		return
	end

	tryReserveMatch(modeId)
end

function MatchmakingService.joinQueue(player, modeId)
	if not MatchmakingConfig.MODES[modeId] then
		return
	end
	if callbacks.getPhase and callbacks.getPhase(player) == "arena" then
		return
	end
	if pendingMatch and playerInList(pendingMatch.players, player) then
		return
	end

	removeFromAllQueues(player)
	table.insert(queues[modeId], player)
	playerMode[player] = modeId

	broadcastQueueUpdate(player)
	evaluateMode(modeId)
end

function MatchmakingService.leaveQueue(player)
	if pendingMatch and playerInList(pendingMatch.players, player) then
		local modeId = pendingMatch.modeId
		for _, reserved in pendingMatch.players do
			if reserved ~= player and reserved.Parent then
				table.insert(queues[modeId], reserved)
				playerMode[reserved] = modeId
			end
		end
		pendingMatch = nil
	end

	removeFromAllQueues(player)
	Remotes.QueueUpdate:FireClient(player, { inQueue = false })
	broadcastQueueUpdate()
	onFfaQueueChanged()
end

function MatchmakingService.start(opts)
	callbacks = opts or {}

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		if typeof(modeId) ~= "string" then
			return
		end
		MatchmakingService.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)

	ArenaFree.Event:Connect(function()
		task.defer(tryAllQueues)
	end)

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingService.leaveQueue(player)
	end)
end

return MatchmakingService
