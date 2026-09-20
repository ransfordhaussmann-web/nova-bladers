local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local QueueJoin = Remotes.QueueJoin
local QueueLeave = Remotes.QueueLeave
local QueueUpdate = Remotes.QueueUpdate

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
panel.Size = UDim2.fromOffset(280, 120)
panel.Position = UDim2.new(0.5, -140, 0, 80)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 24)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Warteschlange"
title.Parent = panel

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 48)
status.Position = UDim2.fromOffset(8, 32)
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.TextSize = 13
status.TextColor3 = Color3.new(1, 1, 1)
status.TextXAlignment = Enum.TextXAlignment.Left
status.TextYAlignment = Enum.TextYAlignment.Top
status.Text = ""
status.Parent = panel

local leaveBtn = Instance.new("TextButton")
leaveBtn.Name = "LeaveButton"
leaveBtn.Size = UDim2.fromOffset(120, 28)
leaveBtn.Position = UDim2.new(1, -128, 1, -36)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function formatStatus(payload)
	if payload.status == "pending" then
		return string.format(
			"%s\nArena belegt — warte auf freien Slot\nPosition: %d / %d",
			payload.modeLabel,
			payload.position or 0,
			payload.queueSize or 0
		)
	end
	if payload.status == "full" then
		return string.format("%s\nWarteschlange voll", payload.modeLabel or "Modus")
	end
	return string.format(
		"%s\nSpieler: %d / %d (min. %d)\nPosition: %d",
		payload.modeLabel,
		payload.queueSize or 0,
		payload.maxPlayers or 0,
		payload.minPlayers or 0,
		payload.position or 0
	)
end

QueueUpdate.OnClientEvent:Connect(function(payload)
	gui.Enabled = true
	title.Text = "Warteschlange — " .. (payload.modeLabel or "")
	status.Text = formatStatus(payload)
end)

QueueLeave.OnClientEvent:Connect(function()
	gui.Enabled = false
	status.Text = ""
end)

leaveBtn.MouseButton1Click:Connect(function()
	QueueLeave:FireServer()
	gui.Enabled = false
end)
