local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()
local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate
local MatchReady = Bindables.MatchReady
local MatchEnded = Bindables.MatchEnded

local function getRecommendedModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

local function attachModePadPrompts()
	local hub = workspace:FindFirstChild("Hub")
	if not hub then
		return
	end

	for _, padConfig in HubConfig.MODE_PADS do
		local pad = hub:FindFirstChild("ModePad_" .. padConfig.id)
		if not pad then
			continue
		end
		if pad:FindFirstChild("QueuePrompt") then
			continue
		end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "QueuePrompt"
		prompt.ActionText = "Queue"
		prompt.ObjectText = padConfig.label
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 10
		prompt.RequiresLineOfSight = false
		prompt.Parent = pad

		prompt.Triggered:Connect(function(player)
			MatchmakingService.joinQueue(player, padConfig.id)
		end)
	end
end

MatchmakingService.onQueueUpdate(function(player, payload)
	if player.Parent then
		QueueUpdate:FireClient(player, payload)
	end
end)

MatchmakingService.onMatchReady(function(payload)
	for _, player in payload.players do
		if player.Parent then
			QueueUpdate:FireClient(player, { inQueue = false })
		end
	end
	MatchReady:Fire(payload.mode, payload.players)
end)

Bindables.MatchStarted.Event:Connect(function()
	MatchmakingService.setArenaBusy(true)
end)

MatchEnded.Event:Connect(function()
	MatchmakingService.setArenaBusy(false)
end)

QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = getRecommendedModeId()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

Players.PlayerRemoving:Connect(function(player)
	MatchmakingService.clearPlayer(player)
end)

task.spawn(function()
	while true do
		task.wait(0.5)
		MatchmakingService.checkQueues()
	end
end)

task.defer(attachModePadPrompts)

print("[MatchmakingManager] Queue system ready")

return {
	joinRecommendedQueue = function(player)
		MatchmakingService.joinQueue(player, getRecommendedModeId())
	end,
	getRecommendedModeId = getRecommendedModeId,
}
