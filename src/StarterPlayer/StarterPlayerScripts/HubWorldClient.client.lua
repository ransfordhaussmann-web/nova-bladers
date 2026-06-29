local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HubConfig = require(ReplicatedStorage:WaitForChild("NovaBladers").HubConfig)

local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then
	return
end

local gateFolder = hub:WaitForChild("ArenaGate", 10)
if not gateFolder then
	return
end

local gateGlow = gateFolder:WaitForChild("GateGlow", 5)
if not gateGlow or not gateGlow:GetAttribute("PulseGlow") then
	return
end

local pulseInfo = TweenInfo.new(1.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local pulseTween = TweenService:Create(gateGlow, pulseInfo, {
	Transparency = 0.65,
	Size = gateGlow.Size + Vector3.new(0.6, 0.6, 0),
})
pulseTween:Play()

local light = Instance.new("PointLight")
light.Color = HubConfig.COLORS.arenaGate
light.Brightness = 1.2
light.Range = 14
light.Parent = gateGlow
