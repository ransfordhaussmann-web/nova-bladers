local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local hub = workspace:WaitForChild("NovaBladersHub", 30)
if not hub then
	return
end

local zonesFolder = hub:WaitForChild("Zones")
local activeHighlight = nil

local function findZonePad(zoneId: string)
	local zoneFolder = zonesFolder:FindFirstChild(zoneId)
	if not zoneFolder then return nil end
	return zoneFolder:FindFirstChild("Pad")
end

local function clearHighlight()
	if not activeHighlight then return end
	local pad, tween = activeHighlight.pad, activeHighlight.tween
	if tween then tween:Cancel() end
	if pad and pad.Parent then
		pad.Transparency = 0.25
	end
	activeHighlight = nil
end

local function highlightZone(zoneId: string)
	clearHighlight()
	local pad = findZonePad(zoneId)
	if not pad then return end

	pad.Transparency = 0.05
	local tween = TweenService:Create(pad, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.35,
	})
	tween:Play()
	activeHighlight = { pad = pad, tween = tween }
end

Remotes.HubZoneHighlight.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" or not payload.zoneId then return end
	highlightZone(payload.zoneId)
end)

-- Subtle pad pulse so the walkable hub feels alive even before touch.
for zoneId, zoneConfig in HubConfig.ZONES do
	local pad = findZonePad(zoneId)
	if pad then
		local light = pad:FindFirstChildOfClass("PointLight")
		if light then
			TweenService:Create(light, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Brightness = 1.1,
			}):Play()
		end
	end
end

player.CharacterAdded:Connect(function()
	clearHighlight()
end)
