local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "HubHints"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Name = "HintPanel"
frame.AnchorPoint = Vector2.new(0.5, 0)
frame.Position = UDim2.new(0.5, 0, 0.08, 0)
frame.Size = UDim2.new(0, 360, 0, 72)
frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0.45, 0)
title.Position = UDim2.new(0, 8, 0.08, 0)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextColor3 = Color3.fromRGB(255, 220, 120)
title.TextScaled = true
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0.4, 0)
hint.Position = UDim2.new(0, 8, 0.52, 0)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextScaled = true
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

local function hideHint()
	gui.Enabled = false
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not payload.visible then
		hideHint()
		return
	end
	title.Text = payload.label or "Nova Hub"
	hint.Text = payload.hint or ""
	gui.Enabled = true
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
if not hub then
	return
end

local activeZoneId = nil

local function showZone(zone)
	if activeZoneId == zone.id then
		return
	end
	activeZoneId = zone.id
	title.Text = zone.label
	hint.Text = zone.hint .. " — [E] zum Interagieren"
	gui.Enabled = true
end

local function clearZone(zoneId)
	if activeZoneId == zoneId then
		activeZoneId = nil
		hideHint()
	end
end

for _, zone in HubConfig.ZONES do
	local marker = hub:WaitForChild(zone.id, 10)
	if marker then
		marker.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if character and character == player.Character then
				showZone(zone)
			end
		end)
		marker.TouchEnded:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if character and character == player.Character then
				clearZone(zone.id)
			end
		end)
	end
end
