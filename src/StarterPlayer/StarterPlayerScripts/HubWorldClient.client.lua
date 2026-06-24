local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local promptGui = Instance.new("ScreenGui")
promptGui.Name = "HubZonePrompt"
promptGui.ResetOnSpawn = false
promptGui.Enabled = false
promptGui.Parent = player:WaitForChild("PlayerGui")

local promptFrame = Instance.new("Frame")
promptFrame.Name = "Prompt"
promptFrame.AnchorPoint = Vector2.new(0.5, 1)
promptFrame.Position = UDim2.new(0.5, 0, 1, -80)
promptFrame.Size = UDim2.fromOffset(320, 56)
promptFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
promptFrame.BackgroundTransparency = 0.15
promptFrame.BorderSizePixel = 0
promptFrame.Parent = promptGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = promptFrame

local promptLabel = Instance.new("TextLabel")
promptLabel.Name = "Label"
promptLabel.Size = UDim2.new(1, -20, 1, 0)
promptLabel.Position = UDim2.fromOffset(10, 0)
promptLabel.BackgroundTransparency = 1
promptLabel.Font = Enum.Font.GothamMedium
promptLabel.TextColor3 = Color3.new(1, 1, 1)
promptLabel.TextScaled = true
promptLabel.Text = ""
promptLabel.Parent = promptFrame

local activeZone

local function hidePrompt()
	activeZone = nil
	promptGui.Enabled = false
end

local function showPrompt(zone)
	activeZone = zone
	promptLabel.Text = string.format("[E] %s", zone.prompt)
	promptGui.Enabled = true
end

local function activateZone()
	if not activeZone then return end

	if activeZone.action == "enterArena" then
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
		Remotes.EnterArena:FireServer()
		hidePrompt()
	elseif activeZone.action == "beySelect" then
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then select.Enabled = true end
	elseif activeZone.action == "leaderboard" then
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = true end
	end
end

Remotes.HubZonePrompt.OnClientEvent:Connect(function(zone)
	if zone then
		showPrompt(zone)
	else
		hidePrompt()
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not activeZone then return end
	if input.KeyCode == Enum.KeyCode.E then
		activateZone()
	end
end)

promptFrame.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		activateZone()
	end
end)
