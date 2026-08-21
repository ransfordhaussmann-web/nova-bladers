local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local MatchmakingConfig = require(ReplicatedStorage:WaitForChild("NovaBladers").MatchmakingConfig)

local function getActiveModeId()
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "ffa"
	elseif count == 2 then
		return "pvp"
	end
	return "training"
end

-- Quick queue buttons via chat commands for testing / accessibility
local function onChatted(message)
	local lower = message:lower()
	if lower == "/queue training" or lower == "/queue" then
		local modeId = lower == "/queue" and getActiveModeId() or "training"
		Remotes.QueueJoin:FireServer({ modeId = modeId })
	elseif lower == "/queue pvp" or lower == "/queue 1v1" then
		Remotes.QueueJoin:FireServer({ modeId = "pvp" })
	elseif lower == "/queue ffa" then
		Remotes.QueueJoin:FireServer({ modeId = "ffa" })
	elseif lower == "/leave" or lower == "/queue leave" then
		Remotes.QueueLeave:FireServer()
	end
end

player.Chatted:Connect(onChatted)

-- Expose mode labels for other clients
local modeLabels = {}
for _, config in MatchmakingConfig.MODES do
	modeLabels[config.id] = config.label
end
