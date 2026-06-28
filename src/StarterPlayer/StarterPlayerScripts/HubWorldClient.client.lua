local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HubConfig = require(ReplicatedStorage:WaitForChild("NovaBladers").HubConfig)

local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then return end

local zones = hub:WaitForChild("Zones")
local arenaZone = zones:WaitForChild("ArenaGate")
local building = arenaZone:WaitForChild("Building")
local glow = building:FindFirstChild("GateGlow")

if glow then
	local pulseInfo = TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
	local pulse = TweenService:Create(glow, pulseInfo, { Brightness = 4 })
	pulse:Play()
end

local gateColor = HubConfig.ZONES.ArenaGate.color
local pulseInfo = TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true)
local colorPulse = TweenService:Create(building, pulseInfo, {
	Color = HubConfig.ZONES.ArenaGate.glowColor or gateColor,
})
colorPulse:Play()
