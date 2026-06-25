local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneId

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -72)
hintFrame.Size = UDim2.fromOffset(360, 64)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.BackgroundTransparency = 1
titleLabel.Position = UDim2.fromOffset(12, 6)
titleLabel.Size = UDim2.new(1, -24, 0, 26)
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
titleLabel.TextSize = 18
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.BackgroundTransparency = 1
hintLabel.Position = UDim2.fromOffset(12, 32)
hintLabel.Size = UDim2.new(1, -24, 0, 22)
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
hintLabel.TextSize = 14
hintLabel.TextXAlignment = Enum.TextXAlignment.Left
hintLabel.Parent = hintFrame

local function hideLobbyGui()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload then
		currentZoneId = payload.zoneId
		titleLabel.Text = payload.name
		hintLabel.Text = payload.hint
		hintGui.Enabled = true

		if payload.action == "stats" then
			-- Stats panel is shown by LobbyClient when LobbyReady fires.
		else
			local lobby = player.PlayerGui:FindFirstChild("Lobby")
			if lobby then
				lobby.Enabled = false
			end
		end
	else
		currentZoneId = nil
		hintGui.Enabled = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E and currentZoneId then
		remotes.HubInteract:FireServer(currentZoneId)
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(hideLobbyGui)
end)

hideLobbyGui()
