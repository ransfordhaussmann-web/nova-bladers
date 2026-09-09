local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "QueueUI"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(280, 120)
panel.Position = UDim2.new(0.5, -140, 0, 16)
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

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -16, 0, 44)
statusLabel.Position = UDim2.fromOffset(8, 34)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 13
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = ""
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(120, 28)
leaveButton.Position = UDim2.fromOffset(8, 82)
leaveButton.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveButton

local function formatStatus(payload)
	local lines = {
		payload.modeLabel or "Arena",
		string.format("%d / %d Spieler", payload.players or 0, payload.maxPlayers or 1),
	}

	if payload.status == "pending" then
		table.insert(lines, "Arena belegt — warte...")
	elseif payload.status == "starting" then
		table.insert(lines, "Match startet gleich!")
	else
		table.insert(lines, string.format("Noch %d benötigt", math.max(0, (payload.minPlayers or 1) - (payload.players or 0))))
	end

	return table.concat(lines, "\n")
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	title.Text = "Warteschlange — " .. (payload.modeLabel or "Arena")
	statusLabel.Text = formatStatus(payload)
	gui.Enabled = true
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	gui.Enabled = false
end)
