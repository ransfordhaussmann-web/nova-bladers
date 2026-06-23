local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubZoneHint"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Hint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(360, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(14, 18, 32)
hintFrame.BackgroundTransparency = 0.1
hintFrame.Visible = false
hintFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local stroke = Instance.new("UIStroke")
stroke.Color = Color3.fromRGB(80, 160, 255)
stroke.Thickness = 2
stroke.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 1, 0)
hintLabel.Position = UDim2.fromOffset(8, 0)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.fromRGB(230, 235, 250)
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local function setHint(payload)
	currentZone = payload
	if payload then
		hintLabel.Text = string.format("%s — %s", payload.name, payload.hint)
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(setHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function tryZoneAction()
	if not currentZone or not currentZone.zoneId then
		return
	end
	if currentZone.action == "ViewLeaderboard" then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZone.zoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)
