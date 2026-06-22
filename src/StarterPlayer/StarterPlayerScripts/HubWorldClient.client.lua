local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil

local function getOrCreateHintGui()
	local gui = player.PlayerGui:FindFirstChild("HubZoneHint")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubZoneHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.new(0, 360, 0, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.new(0, 12, 0, 8)
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.new(0, 12, 0, 36)
	hint.Size = UDim2.new(1, -24, 0, 28)
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextSize = 16
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.TextWrapped = true
	hint.Parent = frame

	return gui
end

local function showZoneHint(payload)
	local gui = getOrCreateHintGui()
	local panel = gui.Panel
	panel.Title.Text = payload.name or "Zone"
	panel.Hint.Text = payload.hint or ""
	panel.Visible = true
	currentZone = payload.zoneId
end

local function hideZoneHint()
	local gui = player.PlayerGui:FindFirstChild("HubZoneHint")
	if gui then
		gui.Panel.Visible = false
	end
	currentZone = nil
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		hideZoneHint()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not currentZone then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		Remotes.HubZoneAction:FireServer(currentZone)
	end
end)
