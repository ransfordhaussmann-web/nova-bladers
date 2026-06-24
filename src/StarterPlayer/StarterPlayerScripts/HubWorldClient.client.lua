local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local currentAction = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubHUD"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(360, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.2
hintFrame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextScaled = true
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local zoneTitle = Instance.new("TextLabel")
zoneTitle.Name = "ZoneTitle"
zoneTitle.AnchorPoint = Vector2.new(0.5, 0)
zoneTitle.Position = UDim2.new(0.5, 0, 0, 16)
zoneTitle.Size = UDim2.fromOffset(280, 36)
zoneTitle.BackgroundTransparency = 1
zoneTitle.TextColor3 = Color3.fromRGB(180, 200, 255)
zoneTitle.Font = Enum.Font.GothamBold
zoneTitle.TextScaled = true
zoneTitle.Text = "Nova Hub"
zoneTitle.Parent = gui

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not inHub then return end

	currentAction = payload.action
	if payload.zoneId then
		gui.Enabled = true
		zoneTitle.Text = payload.zoneName or ""
		hintLabel.Text = payload.hint or ""
	else
		zoneTitle.Text = "Nova Hub"
		hintLabel.Text = "Erkunde die Zonen: Arena, Bey-Labor, Ruhmeshalle"
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	gui.Enabled = inHub
	if not inHub then
		currentAction = nil
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	inHub = true
	gui.Enabled = true
end)

local function tryZoneAction()
	if not inHub or not currentAction then return end
	Remotes.HubZoneAction:FireServer(currentAction)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)
