local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubService = require(script.Parent.HubService)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function buildPlayerUpdate(player)
	local modeId = MatchmakingService.getPlayerMode(player)
	if not modeId then
		return {
			inQueue = false,
			arenaBusy = MatchmakingService.isArenaBusy(),
		}
	end

	local snapshot = MatchmakingService.getQueueSnapshot(modeId)
	local status = "waiting"
	if MatchmakingService.isArenaBusy() then
		status = "pending"
	elseif snapshot.count >= snapshot.minPlayers and snapshot.fillTimeout > 0 then
		status = "filling"
	end

	local fillRemaining = nil
	if snapshot.fillStartedAt and snapshot.fillTimeout > 0 then
		fillRemaining = math.max(0, math.ceil(snapshot.fillTimeout - (os.clock() - snapshot.fillStartedAt)))
	end

	return {
		inQueue = true,
		status = status,
		modeId = modeId,
		label = snapshot.label,
		desc = snapshot.desc,
		count = snapshot.count,
		minPlayers = snapshot.minPlayers,
		maxPlayers = snapshot.maxPlayers,
		playerNames = snapshot.playerNames,
		fillRemaining = fillRemaining,
		arenaBusy = MatchmakingService.isArenaBusy(),
	}
end

local function broadcastQueueUpdate(player)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
	end
end

local function broadcastAllQueued()
	for _, player in Players:GetPlayers() do
		if MatchmakingService.getPlayerMode(player) then
			broadcastQueueUpdate(player)
		end
	end
end

local function joinQueue(player, modeId)
	if HubService.getPhase(player) == "arena" then
		return
	end
	if MatchmakingService.getPlayerMode(player) then
		MatchmakingService.leaveQueue(player)
	end

	local ok = MatchmakingService.joinQueue(player, modeId)
	if not ok then
		return
	end

	broadcastQueueUpdate(player)
	broadcastAllQueued()
end

local function leaveQueue(player)
	if not MatchmakingService.getPlayerMode(player) then
		return
	end
	MatchmakingService.leaveQueue(player)
	Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
	broadcastAllQueued()
end

local function preparePlayersForMatch(players)
	for _, player in players do
		if player.Parent and HubService.getPhase(player) ~= "arena" then
			HubService.enterArena(player)
		end
	end
end

local function tryLaunchMatch()
	local ready = MatchmakingService.getReadyMatch()
	if not ready then
		return
	end

	MatchmakingService.setArenaBusy(true)
	preparePlayersForMatch(ready.players)
	for _, player in ready.players do
		Remotes.QueueUpdate:FireClient(player, buildPlayerUpdate(player))
	end
	Bindables.MatchReady:Fire(ready.modeId, ready.players)
end

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getRecommendedModeId()
	end
	joinQueue(player, modeId)
	tryLaunchMatch()
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	joinQueue(player, getRecommendedModeId())
	tryLaunchMatch()
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
	broadcastAllQueued()
	tryLaunchMatch()
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
	broadcastAllQueued()
	tryLaunchMatch()
end)

MatchmakingService.setJoinHandler(function(player, modeId)
	joinQueue(player, modeId)
	tryLaunchMatch()
end)

task.spawn(function()
	while true do
		task.wait(MatchmakingConfig.QUEUE_UPDATE_INTERVAL)
		MatchmakingService.pruneDisconnected()
		broadcastAllQueued()
		tryLaunchMatch()
	end
end)

print("[MatchmakingManager] Queue system ready")
