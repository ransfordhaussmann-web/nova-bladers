local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui
local panel
local statusLabel
local leaveButton

local function ensureGui()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "Matchmaking"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "QueuePanel"
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
	title.Text = "Matchmaking"
	title.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "Status"
	statusLabel.Size = UDim2.new(1, -16, 0, 48)
	statusLabel.Position = UDim2.fromOffset(8, 34)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamMedium
	statusLabel.TextSize = 13
	statusLabel.TextColor3 = Color3.new(1, 1, 1)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.TextYAlignment = Enum.TextYAlignment.Top
	statusLabel.TextWrapped = true
	statusLabel.Text = ""
	statusLabel.Parent = panel

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.Size = UDim2.fromOffset(120, 28)
	leaveButton.Position = UDim2.fromOffset(8, 82)
	leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.TextSize = 13
	leaveButton.TextColor3 = Color3.new(1, 1, 1)
	leaveButton.Text = "Verlassen"
	leaveButton.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = leaveButton

	leaveButton.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)
end

local function formatStatus(payload)
	if payload.status == "pending" then
		return string.format(
			"%s\nArena belegt — warten...\nSpieler: %d / %d",
			payload.modeLabel,
			payload.count,
			payload.maxPlayers
		)
	end

	return string.format(
		"%s\nSpieler: %d / %d (min. %d)",
		payload.modeLabel,
		payload.count,
		payload.maxPlayers,
		payload.minPlayers
	)
end

local function hideQueue()
	ensureGui()
	gui.Enabled = false
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	ensureGui()

	if payload.status == "idle" or not payload.modeId then
		hideQueue()
		return
	end

	gui.Enabled = true
	statusLabel.Text = formatStatus(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)
