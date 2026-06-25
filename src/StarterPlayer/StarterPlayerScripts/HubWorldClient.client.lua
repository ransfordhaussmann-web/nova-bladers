local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "HubWorldUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "ZoneHint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.new(0, 420, 0, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
hintFrame.BackgroundTransparency = 0.15
hintFrame.Visible = false
hintFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
hintLabel.TextScaled = true
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.Parent = hintFrame

local inHub = true

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true and payload.inArena ~= true
	if not inHub then
		hintFrame.Visible = false
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not inHub then
		hintFrame.Visible = false
		return
	end
	if payload.active then
		hintLabel.Text = string.format("%s — %s", payload.name, payload.hint)
		hintFrame.Visible = true
	else
		hintFrame.Visible = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not inHub then return end
	if input.KeyCode == Enum.KeyCode.E then
		Remotes.HubInteract:FireServer()
	end
end)
