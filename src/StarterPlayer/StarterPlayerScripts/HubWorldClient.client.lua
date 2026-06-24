local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubZoneHint"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local label = Instance.new("TextLabel")
label.Name = "Hint"
label.AnchorPoint = Vector2.new(0.5, 1)
label.Position = UDim2.new(0.5, 0, 0.92, 0)
label.Size = UDim2.fromOffset(420, 56)
label.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
label.BackgroundTransparency = 0.15
label.BorderSizePixel = 0
label.TextColor3 = Color3.new(1, 1, 1)
label.TextSize = 20
label.Font = Enum.Font.GothamMedium
label.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = label

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload then
		currentZone = payload
		label.Text = payload.name .. " — " .. payload.hint
		gui.Enabled = true
	else
		currentZone = nil
		gui.Enabled = false
	end
end)

local function tryZoneAction()
	if not currentZone or not currentZone.action then
		return
	end
	if currentZone.action == "viewLeaderboard" then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZone.action)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)
