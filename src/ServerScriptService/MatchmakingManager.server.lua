local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubService = require(script.Parent.HubService)
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(ReplicatedStorage.NovaBladers.MatchmakingService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

local function leaveHubForArena(player)
	HubService.enterArena(player)
end

local function joinQueue(player, modeId)
	if HubService.getPhase(player) ~= "hub" then
		return
	end
	MatchmakingService.joinQueue(player, modeId, leaveHubForArena)
end

MatchmakingService.setCallbacks(function(players, modeId)
	Bindables.MatchReady:Fire(players, modeId)
end, function(player, payload)
	if player.Parent then
		Remotes.QueueUpdate:FireClient(player, payload)
	end
end)

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.resolveDefaultMode(#Players:GetPlayers())
	end
	joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Bindables.MatchEnded.Event:Connect(function()
	MatchmakingService.onMatchEnded(leaveHubForArena)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.onPlayerRemoving(player)
end)

local lastTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick < MatchmakingConfig.QUEUE_TICK_INTERVAL then
		return
	end
	lastTick = now
	MatchmakingService.tick(leaveHubForArena)
end)

local function attachModePadPrompts()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	for modeId, config in MatchmakingConfig.MODES do
		local pad = hub:FindFirstChild("ModePad_" .. modeId)
		if not pad then
			continue
		end

		local prompt = pad:FindFirstChild("JoinQueuePrompt")
		if not prompt then
			prompt = Instance.new("ProximityPrompt")
			prompt.Name = "JoinQueuePrompt"
			prompt.ActionText = "Warteschlange"
			prompt.ObjectText = config.label
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = pad
		end

		prompt.Triggered:Connect(function(player)
			joinQueue(player, modeId)
		end)
	end
end

task.defer(attachModePadPrompts)

print("[MatchmakingManager] Queue system ready")
