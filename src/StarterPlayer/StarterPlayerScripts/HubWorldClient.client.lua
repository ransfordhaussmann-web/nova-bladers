local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then
	return
end

local PULSE_INFO = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)

local function pulseGlow(part)
	local tween = TweenService:Create(part, PULSE_INFO, { Transparency = 0.65 })
	tween:Play()
end

local arch = hub:FindFirstChild("ArenaGateArch")
if arch then
	local glow = arch:FindFirstChild("GateGlow")
	if glow and glow:GetAttribute("PulseGlow") then
		pulseGlow(glow)
	end
end

local remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
local zonesFolder = hub:WaitForChild("Zones")

local function highlightZone(zoneId, active)
	local pad = zonesFolder:FindFirstChild(zoneId)
	if not pad then
		return
	end
	pad.Transparency = active and 0.05 or 0.15
end

remotes.HubStateChanged.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		for _, pad in zonesFolder:GetChildren() do
			if pad:IsA("BasePart") then
				pad.Transparency = 0.15
			end
		end
	end
end)

for _, pad in zonesFolder:GetChildren() do
	if not pad:IsA("BasePart") then
		continue
	end
	local prompt = pad:FindFirstChild("ZonePrompt")
	if not prompt then
		continue
	end
	prompt.PromptShown:Connect(function()
		local zoneId = pad:GetAttribute("ZoneId")
		if zoneId then
			highlightZone(zoneId, true)
		end
	end)
	prompt.PromptHidden:Connect(function()
		local zoneId = pad:GetAttribute("ZoneId")
		if zoneId then
			highlightZone(zoneId, false)
		end
	end)
end
