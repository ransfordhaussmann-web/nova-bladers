local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local MatchmakingManager = {}

local Remotes
local Bindables
local initialized = false

local function fireQueueUpdate(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end

local function buildPlayerPayload(player)
	local modeId = MatchmakingService.getPlayerMode(player)
	if not modeId then
		return { queued = false }
	end

	local snapshot = MatchmakingService.getQueueSnapshot(modeId)
	return {
		queued = true,
		modeId = modeId,
		label = snapshot.label,
		count = snapshot.count,
		minPlayers = snapshot.minPlayers,
		maxPlayers = snapshot.maxPlayers,
		status = snapshot.status,
		arenaBusy = MatchmakingService.isArenaBusy(),
	}
end

local function broadcastQueueUpdates()
	for _, player in Players:GetPlayers() do
		if MatchmakingService.isQueued(player) then
			fireQueueUpdate(player, buildPlayerPayload(player))
		end
	end
end

local function notifyQueueChange(modeId)
	for _, player in Players:GetPlayers() do
		if MatchmakingService.getPlayerMode(player) == modeId then
			fireQueueUpdate(player, buildPlayerPayload(player))
		end
	end
end

local function tryStartNextMatch()
	local result, modeId = MatchmakingService.tryLaunchAll()
	if not result then
		broadcastQueueUpdates()
		return
	end

	MatchmakingService.setArenaBusy(true)
	for _, player in result do
		fireQueueUpdate(player, { queued = false, launching = true, modeId = modeId })
	end
	Bindables.MatchReady:Fire(result, modeId)
end

function MatchmakingManager.joinQueue(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.getRecommendedMode(#Players:GetPlayers())
	end

	local ok, reason = MatchmakingService.joinQueue(player, modeId)
	if not ok then
		fireQueueUpdate(player, {
			queued = false,
			error = reason,
		})
		return false, reason
	end

	fireQueueUpdate(player, buildPlayerPayload(player))
	notifyQueueChange(modeId)

	local snapshot = MatchmakingService.getQueueSnapshot(modeId)
	if snapshot.count >= snapshot.minPlayers and snapshot.count < snapshot.maxPlayers then
		MatchmakingService.scheduleFillTimer(modeId, function()
			tryStartNextMatch()
		end)
	end

	tryStartNextMatch()
	return true, modeId
end

function MatchmakingManager.leaveQueue(player)
	local modeId = MatchmakingService.leaveQueue(player)
	if not modeId then
		return
	end

	fireQueueUpdate(player, { queued = false })
	notifyQueueChange(modeId)
end

function MatchmakingManager.init()
	if initialized then
		return
	end
	initialized = true

	Remotes, Bindables = RemotesSetup.ensure()

	Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
		MatchmakingManager.joinQueue(player, modeId)
	end)

	Remotes.QueueLeave.OnServerEvent:Connect(function(player)
		MatchmakingManager.leaveQueue(player)
	end)

	Bindables.MatchEnded.Event:Connect(function()
		MatchmakingService.setArenaBusy(false)
		task.defer(tryStartNextMatch)
	end)

	Players.PlayerRemoving:Connect(function(player)
		local modeId = MatchmakingService.clearPlayer(player)
		if modeId then
			notifyQueueChange(modeId)
			task.defer(tryStartNextMatch)
		end
	end)

	task.spawn(function()
		while true do
			task.wait(MatchmakingConfig.QUEUE_BROADCAST_INTERVAL)
			broadcastQueueUpdates()
		end
	end)
end

MatchmakingManager.init()

return MatchmakingManager
