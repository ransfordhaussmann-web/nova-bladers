local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then return end

local zones = hub:WaitForChild("Zones", 10)
if not zones then return end

local function stylePrompt(prompt, actionText)
	prompt.ActionText = actionText or prompt.ActionText
	prompt.Style = Enum.ProximityPromptStyle.Custom
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
end

local gateZone = zones:FindFirstChild("ArenaGate")
if gateZone then
	local pad = gateZone:FindFirstChild("Pad")
	local prompt = pad and pad:FindFirstChild("ZonePrompt")
	if prompt then
		stylePrompt(prompt, "Arena betreten")
		prompt.Triggered:Connect(function()
			local remotes = ReplicatedStorage.NovaBladers.Remotes
			remotes.EnterArena:FireServer()
		end)
	end
end

local function bindInfoZone(zoneName)
	local zone = zones:FindFirstChild(zoneName)
	if not zone then return end
	local pad = zone:FindFirstChild("Pad")
	local prompt = pad and pad:FindFirstChild("ZonePrompt")
	if prompt then
		stylePrompt(prompt, "Ansehen")
		prompt.Enabled = true
	end
end

bindInfoZone("Leaderboard")
bindInfoZone("BeyShowcase")

local character = player.Character or player.CharacterAdded:Wait()
local humanoid = character:WaitForChild("Humanoid")
humanoid.WalkSpeed = 16
humanoid.JumpPower = 50

player.CharacterAdded:Connect(function(char)
	local hum = char:WaitForChild("Humanoid")
	hum.WalkSpeed = 16
	hum.JumpPower = 50
end)
