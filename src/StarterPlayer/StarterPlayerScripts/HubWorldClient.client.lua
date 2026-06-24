local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil
local inHub = true

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
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 32)
titleLabel.Position = UDim2.new(0, 8, 0, 8)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = Color3.fromRGB(255, 220, 120)
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 24)
hintLabel.Position = UDim2.new(0, 8, 0, 40)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextScaled = true
hintLabel.Font = Enum.Font.Gotham
hintLabel.Parent = hintFrame

local function hideHint()
	currentZone = nil
	hintGui.Enabled = false
end

local function showHint(payload)
	if not inHub or not payload then
		hideHint()
		return
	end
	currentZone = payload
	titleLabel.Text = payload.label or ""
	hintLabel.Text = payload.hint or ""
	hintGui.Enabled = true
end

local function fireZoneAction()
	if not inHub or not currentZone or not currentZone.action then
		return
	end
	Remotes.HubZoneAction:FireServer(currentZone.action)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	inHub = true
	hideHint()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		fireZoneAction()
	end
end)

hintFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		fireZoneAction()
	end
end)

local lobbyReady = Remotes:FindFirstChild("LobbyReady")
if lobbyReady then
	lobbyReady.OnClientEvent:Connect(function(payload)
		if payload and payload.inHub ~= nil then
			inHub = payload.inHub
			if not inHub then
				hideHint()
			end
		end
	end)
end
