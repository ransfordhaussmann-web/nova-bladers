local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function getRecommendedMode()
	return MatchmakingService.getRecommendedMode(#Players:GetPlayers())
end

local function sendQueueUpdate(player, snapshot, status, pendingReason)
	Remotes.QueueUpdate:FireClient(player, {
		inQueue = status ~= "idle",
		status = status,
		mode = snapshot.mode,
		label = snapshot.label,
		count = snapshot.count,
		minPlayers = snapshot.minPlayers,
		maxPlayers = snapshot.maxPlayers,
		players = snapshot.players,
		pendingReason = pendingReason,
	})
end

local function buildSnapshot(modeId)
	local mode = MatchmakingConfig.MODES[modeId]
	local players = {}
	for _, player in Players:GetPlayers() do
		if MatchmakingService.getPlayerMode(player) == modeId then
			table.insert(players, {
				userId = player.UserId,
				name = player.DisplayName,
			})
		end
	end
	return {
		mode = modeId,
		label = mode.label,
		players = players,
		count = #players,
		minPlayers = mode.minPlayers,
		maxPlayers = mode.maxPlayers,
		fillTimeout = mode.fillTimeout,
	}
end

local function joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end

	local ok, reason = MatchmakingService.joinQueue(player, modeId)
	if not ok then
		sendQueueUpdate(player, buildSnapshot(modeId), "error", reason)
		return
	end

	local snapshot = buildSnapshot(modeId)
	sendQueueUpdate(player, snapshot, "waiting")
end

local function leaveQueue(player)
	local modeId = MatchmakingService.getPlayerMode(player)
	MatchmakingService.leaveQueue(player)
	if modeId then
		sendQueueUpdate(player, buildSnapshot(modeId), "idle")
	else
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "idle" })
	end
end

MatchmakingService.register({
	onQueueUpdate = function(player, snapshot)
		sendQueueUpdate(player, snapshot, "waiting")
	end,
	onPlayerJoined = function(player, modeId, snapshot)
		sendQueueUpdate(player, snapshot, "waiting")
	end,
	onPlayerLeft = function(player, _modeId)
		Remotes.QueueUpdate:FireClient(player, { inQueue = false, status = "idle" })
	end,
	onQueuePending = function(player, match)
		local snapshot = buildSnapshot(match.mode)
		sendQueueUpdate(player, snapshot, "pending", "arena_busy")
	end,
	onMatchReady = function(match)
		for _, player in match.players do
			HubService.leaveHubForArena(player)
		end
		Bindables.MatchReady:Fire(match)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getRecommendedMode()
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	leaveQueue(player)
end)

Remotes.EnterArena.OnServerEvent:Connect(function(player)
	joinQueue(player, getRecommendedMode())
end)

local function setupModePadPrompts()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		local modeId = child.Name:match("^ModePad_(.+)$")
		if modeId and MatchmakingConfig.MODES[modeId] then
			local mode = MatchmakingConfig.MODES[modeId]
			local prompt = child:FindFirstChild("QueuePrompt")
			if not prompt then
				prompt = Instance.new("ProximityPrompt")
				prompt.Name = "QueuePrompt"
				prompt.ActionText = "Queue"
				prompt.ObjectText = mode.label
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 10
				prompt.RequiresLineOfSight = false
				prompt.Parent = child
			end

			prompt.Triggered:Connect(function(player)
				joinQueue(player, modeId)
			end)
		end
	end

	local portal = hub:FindFirstChild("ArenaPortal")
	if portal then
		local portalPrompt = portal:FindFirstChild("EnterArenaPrompt")
		if portalPrompt then
			portalPrompt.ActionText = "Queue beitreten"
			portalPrompt.Triggered:Connect(function(player)
				joinQueue(player, getRecommendedMode())
			end)
		end
	end
end

task.defer(setupModePadPrompts)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

print("[MatchmakingManager] Queue ready — Training / PvP / FFA")
