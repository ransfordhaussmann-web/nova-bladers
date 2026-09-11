local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:FindFirstChild("MatchmakingQueue")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "MatchmakingQueue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 16)
	panel.Size = UDim2.fromOffset(320, 120)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "TitleLabel"
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
	status.Size = UDim2.new(1, -16, 0, 48)
	status.Position = UDim2.fromOffset(8, 34)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 14
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.TextWrapped = true
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
end

local panel = gui.Panel
local statusLabel = panel.StatusLabel
local titleLabel = panel.TitleLabel

local function hideQueue()
	gui.Enabled = false
end

local function showQueue(payload)
	if not payload.inQueue then
		hideQueue()
		return
	end

	gui.Enabled = true
	titleLabel.Text = string.format("Warteschlange — %s", payload.label or "Arena")

	local lines = {
		string.format("Spieler: %d / %d", payload.count or 1, payload.maxPlayers or 1),
	}

	if payload.pending then
		table.insert(lines, "Arena belegt — Match startet gleich...")
	elseif payload.count and payload.minPlayers and payload.count < payload.minPlayers then
		table.insert(lines, string.format("Warte auf %d Spieler...", payload.minPlayers - payload.count))
	else
		table.insert(lines, "Match startet bald...")
	end

	statusLabel.Text = table.concat(lines, "\n")
end

panel.LeaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)
