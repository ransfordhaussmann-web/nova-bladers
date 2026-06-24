local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Panel"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -80)
hintFrame.Size = UDim2.new(0, 320, 0, 72)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 28)
titleLabel.Position = UDim2.new(0, 8, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(90, 160, 255)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 24)
hintLabel.Position = UDim2.new(0, 8, 0, 36)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.fromRGB(220, 220, 230)
hintLabel.TextSize = 15
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not payload then
		activeZone = nil
		hintGui.Enabled = false
		return
	end

	activeZone = payload
	titleLabel.Text = payload.label or "Zone"
	hintLabel.Text = payload.hint or ""
	hintGui.Enabled = true
end)

local function tryZoneAction()
	if not activeZone or not activeZone.action then return end
	if activeZone.action == "viewLeaderboard" then
		Remotes.HubZoneAction:FireServer(activeZone.action)
		return
	end
	Remotes.HubZoneAction:FireServer(activeZone.action)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	hintGui.Enabled = false
	activeZone = nil
end)
