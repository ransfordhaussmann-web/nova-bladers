local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then
	return
end

local arenaGate = hub:WaitForChild("ArenaGate", 10)
if not arenaGate then
	return
end

local building = arenaGate:WaitForChild("Building", 10)
if not building or not building:IsA("BasePart") then
	return
end

local glowColor = HubConfig.GATE_GLOW_COLOR
local baseColor = building.Color
local t = 0

RunService.RenderStepped:Connect(function(dt)
	t += dt
	local pulse = 0.5 + 0.5 * math.sin(t * 2.5)
	building.Color = baseColor:Lerp(glowColor, pulse * 0.45)
	building.Transparency = 0.15 + pulse * 0.15
end)
