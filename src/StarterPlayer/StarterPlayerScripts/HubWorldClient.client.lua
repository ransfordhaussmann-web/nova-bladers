local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil
local inHub = true

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 5
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -120)
hintLabel.Size = UDim2.fromOffset(420, 56)
hintLabel.BackgroundColor3 = Color3.fromRGB(18, 22, 34)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 16
hintLabel.Text = ""
hintLabel.Visible = false
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintLabel

local function setHintVisible(visible, text)
	hintLabel.Visible = visible
	if text then
		hintLabel.Text = text
	end
end

local function hideLobbyGui()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end

remotes.HubZoneAction.OnClientEvent:Connect(function(payload)
	if payload.state == "entered" then
		inHub = true
		currentZone = payload
		hideLobbyGui()
		setHintVisible(true, string.format("%s — %s", payload.name, payload.hint))
	elseif payload.state == "left" then
		currentZone = nil
		setHintVisible(false)
	elseif payload.state == "leftHub" then
		inHub = false
		currentZone = nil
		setHintVisible(false)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not currentZone then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if currentZone.action == "enterArena" then
		remotes.EnterArena:FireServer()
	else
		remotes.HubZoneAction:FireServer("interact")
	end
end)

player.CharacterAdded:Connect(function()
	task.wait(0.5)
	if inHub then
		hideLobbyGui()
	end
end)

hideLobbyGui()
