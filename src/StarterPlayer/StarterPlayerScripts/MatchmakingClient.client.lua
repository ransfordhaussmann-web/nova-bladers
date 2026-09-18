local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "QueuePanel"
panel.AnchorPoint = Vector2.new(0.5, 1)
panel.Position = UDim2.new(0.5, 0, 1, -24)
panel.Size = UDim2.fromOffset(360, 72)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -110, 1, -12)
statusLabel.Position = UDim2.fromOffset(12, 6)
statusLabel.BackgroundTransparency = 1
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 14
statusLabel.TextColor3 = Color3.new(1, 1, 1)
statusLabel.TextXAlignment = Enum.TextXAlignment.Left
statusLabel.TextYAlignment = Enum.TextYAlignment.Top
statusLabel.Text = "Warteschlange..."
statusLabel.Parent = panel

local leaveButton = Instance.new("TextButton")
leaveButton.Name = "LeaveButton"
leaveButton.Size = UDim2.fromOffset(88, 32)
leaveButton.Position = UDim2.new(1, -100, 0.5, -16)
leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveButton.Font = Enum.Font.GothamBold
leaveButton.TextSize = 13
leaveButton.TextColor3 = Color3.new(1, 1, 1)
leaveButton.Text = "Verlassen"
leaveButton.Parent = panel

local leaveCorner = Instance.new("UICorner")
leaveCorner.CornerRadius = UDim.new(0, 6)
leaveCorner.Parent = leaveButton

local function formatStatus(payload)
	if payload.matchStarting then
		return "Match startet..."
	end

	local countText = string.format("%d/%d", payload.count or 0, payload.maxPlayers or 0)
	local statusText = string.format("Warteschlange: %s (%s)", payload.modeLabel or "?", countText)

	if payload.pending then
		statusText ..= "\nArena belegt — bitte warten..."
	elseif payload.fillSecondsLeft and payload.fillSecondsLeft > 0 then
		statusText ..= string.format("\nStart in %ds", payload.fillSecondsLeft)
	elseif payload.count and payload.minPlayers and payload.count < payload.minPlayers then
		statusText ..= "\nWarte auf Gegner..."
	end

	return statusText
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if not payload.inQueue and not payload.matchStarting then
		gui.Enabled = false
		return
	end

	statusLabel.Text = formatStatus(payload)
	gui.Enabled = true

	if payload.matchStarting then
		task.delay(2, function()
			if gui.Enabled then
				gui.Enabled = false
			end
		end)
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)
