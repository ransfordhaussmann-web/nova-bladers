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
hintFrame.Size = UDim2.fromOffset(420, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
hintFrame.BackgroundTransparency = 0.2
hintFrame.BorderSizePixel = 0
hintFrame.Visible = false
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(12, 6)
titleLabel.Size = UDim2.new(1, -24, 0, 18)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextSize = 14
titleLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.BackgroundTransparency = 1
hintLabel.Position = UDim2.fromOffset(12, 24)
hintLabel.Size = UDim2.new(1, -24, 0, 24)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.TextWrapped = true
hintLabel.Parent = hintFrame

local hintToken = 0

local function hideBattleUi()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function showHubUi()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
	hideBattleUi()
end

local function showHint(zoneTitle: string, hintText: string)
	hintToken += 1
	local token = hintToken
	titleLabel.Text = zoneTitle
	hintLabel.Text = hintText
	hintFrame.Visible = true

	task.delay(4, function()
		if token == hintToken then
			hintFrame.Visible = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(hintText, zoneTitle)
	showHint(zoneTitle or "Nova Hub", hintText or "")
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hintFrame.Visible = false
	showHubUi()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	hintFrame.Visible = false
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
end)

showHubUi()
