local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hubFolder = workspace:WaitForChild("NovaBladersHub", 30)
local zonesFolder = hubFolder and hubFolder:FindFirstChild("Zones")

local activeHighlight
local activeTween

local function getZoneDisc(zoneId)
	if not zonesFolder then
		return nil
	end
	return zonesFolder:FindFirstChild(zoneId)
end

local function clearHighlight()
	if activeTween then
		activeTween:Cancel()
		activeTween = nil
	end
	if activeHighlight then
		activeHighlight.Transparency = 0.55
		activeHighlight = nil
	end
end

local function highlightZone(zoneId)
	clearHighlight()
	if not zoneId then
		return
	end

	local disc = getZoneDisc(zoneId)
	if not disc then
		return
	end

	activeHighlight = disc
	local zone = HubConfig.ZONES[zoneId]
	local targetTransparency = 0.15

	activeTween = TweenService:Create(
		disc,
		TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Transparency = targetTransparency }
	)
	activeTween:Play()

	if zone then
		disc.Color = zone.color
	end
end

Remotes.HubZoneHighlight.OnClientEvent:Connect(highlightZone)

-- Proximity-Prompt-Hinweis in der Lobby-UI
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")
local hintLabel = panel:FindFirstChild("HubHintLabel")

if not hintLabel then
	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HubHintLabel"
	hintLabel.Size = UDim2.new(1, -20, 0, 36)
	hintLabel.Position = UDim2.new(0, 10, 1, -46)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextSize = 14
	hintLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
	hintLabel.TextWrapped = true
	hintLabel.Text = "Laufe zu einer Zone oder nutze Start"
	hintLabel.Parent = panel
end

Remotes.HubZoneHighlight.OnClientEvent:Connect(function(zoneId)
	if zoneId and HubConfig.ZONES[zoneId] then
		hintLabel.Text = string.format(
			"In Zone: %s — E drücken oder Start",
			HubConfig.ZONES[zoneId].label
		)
	else
		hintLabel.Text = "Laufe zu Training, 1v1 oder FFA"
	end
end)
