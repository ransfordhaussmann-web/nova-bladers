local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 5
hintGui.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.new(0, 420, 0, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Visible = false
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.new(1, -20, 1, -16)
hintLabel.Position = UDim2.new(0, 10, 0, 8)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
hintLabel.TextSize = 16
hintLabel.TextWrapped = true
hintLabel.TextXAlignment = Enum.TextXAlignment.Center
hintLabel.TextYAlignment = Enum.TextYAlignment.Center
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local statsGui = Instance.new("ScreenGui")
statsGui.Name = "HubStatsHUD"
statsGui.ResetOnSpawn = false
statsGui.DisplayOrder = 4
statsGui.Enabled = false
statsGui.Parent = playerGui

local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsFrame"
statsFrame.AnchorPoint = Vector2.new(0, 0)
statsFrame.Position = UDim2.new(0, 16, 0, 16)
statsFrame.Size = UDim2.new(0, 200, 0, 88)
statsFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
statsFrame.BackgroundTransparency = 0.2
statsFrame.BorderSizePixel = 0
statsFrame.Parent = statsGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 8)
statsCorner.Parent = statsFrame

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, -16, 1, -16)
statsLabel.Position = UDim2.new(0, 8, 0, 8)
statsLabel.BackgroundTransparency = 1
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
statsLabel.TextSize = 14
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = ""
statsLabel.Parent = statsFrame

local modeLabel = Instance.new("TextLabel")
modeLabel.Name = "ModeLabel"
modeLabel.AnchorPoint = Vector2.new(0, 0)
modeLabel.Position = UDim2.new(0, 16, 0, 112)
modeLabel.Size = UDim2.new(0, 200, 0, 24)
modeLabel.BackgroundTransparency = 1
modeLabel.Font = Enum.Font.GothamBold
modeLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
modeLabel.TextSize = 14
modeLabel.TextXAlignment = Enum.TextXAlignment.Left
modeLabel.Text = ""
modeLabel.Parent = statsGui

local hintToken = 0

local function showHint(text, duration)
	if text == "" or not text then
		hintFrame.Visible = false
		return
	end

	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintFrame.Visible = true

	task.delay(duration or 4, function()
		if token == hintToken then
			hintFrame.Visible = false
		end
	end)
end

local function updateHubStats(payload)
	statsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0
	)
	modeLabel.Text = payload.modeLabel or ""
	statsGui.Enabled = true
end

local function hideHubUI()
	statsGui.Enabled = false
	showHint("")
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	if payload.hideHud then
		hideHubUI()
		return
	end
	showHint(payload.text, payload.duration)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local beySelect = playerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.hubMode then
		updateHubStats(payload)
	else
		hideHubUI()
	end
end)
