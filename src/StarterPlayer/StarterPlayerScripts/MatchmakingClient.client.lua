local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local playerGui = player:WaitForChild("PlayerGui")

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -24)
panel.Size = UDim2.fromOffset(320, 92)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 22)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Warteschlange"
title.Parent = panel

local message = Instance.new("TextLabel")
message.Name = "Message"
message.Size = UDim2.new(1, -16, 0, 36)
message.Position = UDim2.fromOffset(8, 30)
message.BackgroundTransparency = 1
message.Font = Enum.Font.GothamMedium
message.TextSize = 13
message.TextColor3 = Color3.new(1, 1, 1)
message.TextXAlignment = Enum.TextXAlignment.Left
message.TextYAlignment = Enum.TextYAlignment.Top
message.TextWrapped = true
message.Text = ""
message.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(96, 24)
leaveButton.Position = UDim2.new(1, -104, 1, -32)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 12
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function hideQueue()
	gui.Enabled = false
end

local function showQueue(payload)
	gui.Enabled = true
	title.Text = string.format("Warteschlange — %s", payload.modeLabel or "Match")
	message.Text = payload.message or "Suche Gegner..."

	if payload.status == "pending" then
		title.TextColor3 = Color3.fromRGB(255, 180, 90)
	elseif payload.status == "starting" then
		title.TextColor3 = Color3.fromRGB(120, 255, 160)
	else
		title.TextColor3 = Color3.fromRGB(120, 180, 255)
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		showQueue(payload)
	else
		hideQueue()
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)
