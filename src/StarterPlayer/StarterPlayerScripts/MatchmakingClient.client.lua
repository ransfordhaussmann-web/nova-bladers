local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:FindFirstChild("Queue")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "Queue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.fromOffset(300, 110)
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
	status.Name = "StatusLabel"
	status.Size = UDim2.new(1, -16, 0, 40)
	status.Position = UDim2.fromOffset(8, 34)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 13
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Text = "Warte auf Spieler..."
	status.Parent = panel

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveButton"
	leaveBtn.Size = UDim2.fromOffset(120, 28)
	leaveBtn.Position = UDim2.new(1, -128, 1, -36)
	leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 60, 60)
	leaveBtn.Font = Enum.Font.GothamBold
	leaveBtn.TextSize = 13
	leaveBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveBtn.Text = "Verlassen"
	leaveBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = leaveBtn
end

local panel = gui.Panel
local statusLabel = panel.StatusLabel
local titleLabel = panel.Title
local leaveButton = panel.LeaveButton

local function hideQueue()
	gui.Enabled = false
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end

local function showQueue(payload)
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	gui.Enabled = true

	titleLabel.Text = "Warteschlange — " .. (payload.label or payload.mode or "?")

	if payload.status == "pending" then
		statusLabel.Text = string.format(
			"Match bereit — Arena belegt\n%d Spieler warten auf Freigabe",
			payload.total or 0
		)
	else
		statusLabel.Text = string.format(
			"%d / %d Spieler\nPosition: %d",
			payload.total or 0,
			payload.required or payload.maxPlayers or 1,
			payload.position or 0
		)
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "pending" or (payload.total and payload.total > 0) then
		showQueue(payload)
	else
		hideQueue()
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hideQueue()
	elseif state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.MatchState.OnClientEvent:Connect(function()
	hideQueue()
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)
