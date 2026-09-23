local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)
local MatchmakingService = require(script.Parent.MatchmakingService)
local MatchStateService = require(script.Parent.MatchStateService)
local HubService = require(script.Parent.HubService)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

local Remotes, Bindables = RemotesSetup.ensure()

MatchmakingService.registerHandlers({
	onQueueUpdate = function(player, payload)
		Remotes.QueueUpdate:FireClient(player, payload)
	end,
	onMatchReady = function(players, modeId)
		if MatchStateService.isBusy() then
			return
		end

		MatchStateService.setBusy(true)

		for _, player in players do
			HubService.leaveHubForArena(player)
		end

		Bindables.MatchReady:Fire(players, modeId)
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingConfig.DEFAULT_MODE
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

local function attachModePadPrompts()
	local hub = workspace:WaitForChild("Hub", 10)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		local modeId = child.Name:match("^ModePad_(.+)$")
		if modeId and not child:FindFirstChild("QueuePrompt") then
			local mode = MatchmakingConfig.getMode(modeId)
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "QueuePrompt"
			prompt.ActionText = "Queue beitreten"
			prompt.ObjectText = mode.label
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.HoldDuration = 0
			prompt.MaxActivationDistance = 10
			prompt.RequiresLineOfSight = false
			prompt.Parent = child

			prompt.Triggered:Connect(function(player)
				MatchmakingService.joinQueue(player, modeId)
			end)
		end
	end
end

task.defer(attachModePadPrompts)

print("[MatchmakingManager] Queue system ready")
