local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)
local HubService = require(script.Parent.HubService)

local Remotes = RemotesSetup.ensure()

local function getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function getModeLabel(modeId)
	for _, pad in HubConfig.MODE_PADS do
		if pad.id == modeId then
			return pad.label
		end
	end
	return modeId
end

local function setupModePads()
	local hub = workspace:WaitForChild("Hub", 30)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		local modeId = child.Name:match("^ModePad_(.+)$")
		if modeId and child:IsA("BasePart") then
			local prompt = child:FindFirstChild("QueuePrompt")
			if not prompt then
				prompt = Instance.new("ProximityPrompt")
				prompt.Name = "QueuePrompt"
				prompt.ActionText = "Warteschlange"
				prompt.ObjectText = getModeLabel(modeId)
				prompt.KeyboardKeyCode = Enum.KeyCode.E
				prompt.HoldDuration = 0
				prompt.MaxActivationDistance = 12
				prompt.RequiresLineOfSight = false
				prompt.Parent = child
			end

			prompt.Triggered:Connect(function(player)
				MatchmakingService.joinQueue(player, modeId)
			end)
		end
	end
end

MatchmakingService.register({
	onMatchReady = function(players)
		for _, player in players do
			if HubService.leaveHubForArena then
				HubService.leaveHubForArena(player)
			end
		end
	end,
})

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getActiveModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

task.defer(setupModePads)

print("[MatchmakingManager] Queue system ready")
