local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then
	return
end

local glowParts = {}

for _, descendant in hub:GetDescendants() do
	if descendant:IsA("BasePart") and descendant:GetAttribute("GlowPart") then
		table.insert(glowParts, descendant)
	end
end

local function setZoneHighlight(zoneId)
	for _, zoneFolder in hub.Zones:GetChildren() do
		local marker = zoneFolder:FindFirstChild("ZoneMarker")
		if marker then
			local isActive = zoneFolder.Name == zoneId
			marker.Transparency = isActive and 0.82 or 0.94
		end
	end
end

Remotes.HubZoneChanged.OnClientEvent:Connect(function(zoneId)
	setZoneHighlight(zoneId)
end)

local pulse = 0
RunService.RenderStepped:Connect(function(dt)
	pulse += dt * 2
	local alpha = 0.35 + math.sin(pulse) * 0.15
	for _, part in glowParts do
		part.Transparency = alpha
	end
end)

local function tweenCameraHint(zoneId)
	if zoneId == "ArenaGate" then
		local zone = HubConfig.ZONES.ArenaGate
		local center = HubConfig.ORIGIN + zone.center
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root and (root.Position - center).Magnitude < 16 then
			local highlight = hub.Zones.ArenaGate:FindFirstChild("GatePortal")
			if highlight then
				TweenService:Create(highlight, TweenInfo.new(0.3), {
					Color = Color3.fromRGB(255, 200, 120),
				}):Play()
			end
		end
	end
end

Remotes.HubZoneChanged.OnClientEvent:Connect(tweenCameraHint)

setZoneHighlight("Spawn")
