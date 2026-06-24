local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZoneId

local function getOrCreatePromptGui()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("HubZonePrompt")
	if existing then
		return existing
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubZonePrompt"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -120)
	frame.Size = UDim2.fromOffset(360, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	frame.BackgroundTransparency = 0.1
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 28)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(12, 36)
	hint.Size = UDim2.new(1, -24, 0, 24)
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(180, 190, 210)
	hint.TextSize = 16
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	return gui
end

local promptGui = getOrCreatePromptGui()
local banner = promptGui.Banner
local titleLabel = banner.Title
local hintLabel = banner.Hint

local function hidePrompt()
	activeZoneId = nil
	promptGui.Enabled = false
end

local function showPrompt(payload)
	activeZoneId = payload.zoneId
	titleLabel.Text = payload.label or "Nova Hub"
	hintLabel.Text = payload.hint or "Drücke E"
	promptGui.Enabled = true
end

Remotes.HubZonePrompt.OnClientEvent:Connect(function(payload)
	if payload.clear then
		if activeZoneId == payload.zoneId then
			hidePrompt()
		end
		return
	end
	showPrompt(payload)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not activeZoneId then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		Remotes.HubAction:FireServer(activeZoneId)
	end
end)

hidePrompt()
