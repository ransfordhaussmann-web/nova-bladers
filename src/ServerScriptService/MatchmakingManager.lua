local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchState = require(script.Parent.MatchState)
local HubService = require(script.Parent.HubService)

local MatchmakingManager = {}

local Remotes
local Bindables
local initialized = false

local queues = {}
local playerEntry = {}
local fillTimers = {}

local function initQueues()
	for modeId in MatchmakingConfig.MODES do
		queues[modeId] = {}
		fillTimers[modeId] = 0
	end
end

local function getQueueSnapshot(modeId)
	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return nil
	end

	local names = {}
	for _, player in queues[modeId] do
		if player.Parent then
			table.insert(names, player.Name)
		end
	end

	return {
		modeId = modeId,
		label = mode.label,
		count = #names,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		playerNames = names,
	}
end

local function buildPlayerUpdate(player)
	local entry = playerEntry[player]
	if not entry then
		return { inQueue = false }
	end

	local mode = MatchmakingConfig.getMode(entry.modeId)
	local snapshot = getQueueSnapshot(entry.modeId)
	local status = entry.status

	if MatchState.isBusy() and status == "waiting" then
		status = "pending"
	end

	return {
		inQueue = true,
		modeId = entry.modeId,
		modeLabel = mode and mode.label or entry.modeId,
		status = status,
		position = entry.position,
		queue = snapshot,
		arenaBusy = MatchState.isBusy(),
	}
end

local function broadcastQueueUpdate(targetPlayer)
	if not Remotes then
		return
	end

	if targetPlayer then
		if targetPlayer.Parent then
			Remotes.QueueUpdate:FireClient(targetPlayer, buildPlayerUpdate(targetPlayer))
		end
		return
	end

	for player in playerEntry do
		if player.Parent then
			Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
		end
	end
end

local function removeFromQueue(player)
	local entry = playerEntry[player]
	if not entry then
		return
	end

	local modeId = entry.modeId
	playerEntry[player] = nil

	local queue = queues[modeId]
	for i = #queue, 1, -1 do
		if queue[i] == player then
			table.remove(queue, i)
		end
	end

	for index, queuedPlayer in queues[modeId] do
		if playerEntry[queuedPlayer] then
			playerEntry[queuedPlayer].position = index
		end
	end

	if #queues[modeId] < MatchmakingConfig.getMode(modeId).minPlayers then
		fillTimers[modeId] = 0
	end
end

local function addToQueue(player, modeId)
	removeFromQueue(player)

	local mode = MatchmakingConfig.getMode(modeId)
	if not mode then
		return false, "invalid_mode"
	end

	if HubService.getPhase(player) ~= "hub" then
		return false, "not_in_hub"
	end

	table.insert(queues[modeId], player)
	playerEntry[player] = {
		modeId = modeId,
		status = MatchState.isBusy() and "pending" or "waiting",
		position = #queues[modeId],
	}

	return true
end

local function takePlayers(modeId, count)
	local selected = {}
	local queue = queues[modeId]

	for _ = 1, count do
		local player = table.remove(queue, 1)
		if player and player.Parent then
			table.insert(selected, player)
			playerEntry[player] = nil
		end
	end

	for index, queuedPlayer in queue do
		if playerEntry[queuedPlayer] then
			playerEntry[queuedPlayer].position = index
		end
	end

	fillTimers[modeId] = 0
	return selected
end

local function startMatch(modeId, playerList)
	if #playerList == 0 then
		return
	end

	MatchState.setBusy(true)

	for _, player in playerList do
		HubService.leaveHubForArena(player)
	end

	if Bindables and Bindables.MatchReady then
		Bindables.MatchReady:Fire(playerList, modeId)
	end

	broadcastQueueUpdate()
end

local function tryStartMode(modeId)
	if MatchState.isBusy() then
		return false
	end

	local mode = MatchmakingConfig.getMode(modeId)
	local queue = queues[modeId]
	if #queue < mode.minPlayers then
		return false
	end

	if modeId == "ffa" then
		if #queue >= mode.maxPlayers then
			startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
			return true
		end

		if fillTimers[modeId] == 0 then
			fillTimers[modeId] = os.clock()
			task.delay(mode.fillTimeout, function()
				if MatchState.isBusy() then
					return
				end
				local ffaMode = MatchmakingConfig.getMode("ffa")
				if #queues.ffa >= ffaMode.minPlayers and fillTimers.ffa > 0 then
					local count = math.min(#queues.ffa, ffaMode.maxPlayers)
					startMatch("ffa", takePlayers("ffa", count))
					MatchmakingManager.processQueues()
				end
			end)
		end
		return false
	end

	startMatch(modeId, takePlayers(modeId, mode.maxPlayers))
	return true
end

function MatchmakingManager.processQueues()
	if MatchState.isBusy() then
		return
	end

	for _, modeId in MatchmakingConfig.START_PRIORITY do
		if tryStartMode(modeId) then
			return
		end
	end
end

function MatchmakingManager.joinQueue(player, modeId)
	MatchmakingManager.ensureInitialized()
	if typeof(modeId) ~= "string" then
		return false, "invalid_mode"
	end

	local ok, reason = addToQueue(player, modeId)
	if not ok then
		return false, reason
	end

	broadcastQueueUpdate()
	broadcastQueueUpdate(player)
	MatchmakingManager.processQueues()
	return true
end

function MatchmakingManager.leaveQueue(player)
	MatchmakingManager.ensureInitialized()
	if not playerEntry[player] then
		return false
	end

	removeFromQueue(player)
	broadcastQueueUpdate(player)
	broadcastQueueUpdate()
	return true
end

function MatchmakingManager.onMatchEnded()
	MatchState.setBusy(false)

	for player, entry in playerEntry do
		if player.Parent then
			entry.status = "waiting"
		end
	end

	broadcastQueueUpdate()
	MatchmakingManager.processQueues()
end

function MatchmakingManager.onPlayerRemoving(player)
	removeFromQueue(player)
	task.defer(broadcastQueueUpdate)
end

function MatchmakingManager.ensureInitialized()
	if initialized then
		return
	end

	local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
	local remotes, bindables = RemotesSetup.ensure()
	MatchmakingManager.init(remotes, bindables)
end

function MatchmakingManager.init(remotes, bindables)
	if initialized then
		return
	end

	Remotes = remotes
	Bindables = bindables
	initialized = true
	initQueues()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingManager.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)

	if Bindables.MatchEnded then
		Bindables.MatchEnded.Event:Connect(function()
			MatchmakingManager.onMatchEnded()
		end)
	end

	Players.PlayerRemoving:Connect(function(player)
		MatchmakingManager.onPlayerRemoving(player)
	end)
end

return MatchmakingManager
