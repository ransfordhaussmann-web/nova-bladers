local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneId = nil
local currentAction = nil
local inHub = false

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.new(0, 360, 0, 48)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
hintLabel.TextSize = 20
hintLabel.Font = Enum.Font.GothamBold
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintLabel

local function zoneDisplayName(zoneId)
	if zoneId == "arena_gate" then return "Arena-Tor" end
	if zoneId == "bey_lab" then return "Bey-Labor" end
	if zoneId == "hall_of_fame" then return "Ruhmeshalle" end
	return zoneId or ""
end

local function actionLabel(action)
	if action == "enter_arena" then return "Arena betreten" end
	if action == "open_bey_select" then return "Bey wählen" end
	return ""
end

local function updateHint()
	if not inHub or not currentZoneId then
		hintGui.Enabled = false
		return
	end

	hintGui.Enabled = true
	if currentAction and currentAction ~= "none" then
		hintLabel.Text = string.format("[%s]  %s  —  Drücke E", zoneDisplayName(currentZoneId), actionLabel(currentAction))
	else
		hintLabel.Text = zoneDisplayName(currentZoneId)
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		hintGui.Enabled = false
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(zoneId, action)
	currentZoneId = zoneId
	currentAction = action
	updateHint()
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then return end
	if input.KeyCode == Enum.KeyCode.E and currentAction and currentAction ~= "none" then
		Remotes.HubZoneAction:FireServer(currentAction)
	end
end)
