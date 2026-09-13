local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = playerGui:FindFirstChild("Matchmaking")
if not gui then
	gui = Instance.new("ScreenGui")
	gui.Name = "Matchmaking"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 72)
	panel.Size = UDim2.fromOffset(300, 120)
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
	title.TextSize = 15
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
	status.TextSize = 13
	status.TextColor3 = Color3.new(1, 1, 1)
	status.TextXAlignment = Enum.TextXAlignment.Left
	status.TextYAlignment = Enum.TextYAlignment.Top
	status.Text = ""
	status.Parent = panel

	local leaveBtn = Instance.new("TextButton")
	leaveBtn.Name = "LeaveButton"
	leaveBtn.Size = UDim2.fromOffset(120, 28)
	leaveBtn.Position = UDim2.fromOffset(8, 84)
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
local titleLabel = panel.TitleLabel
local statusLabel = panel.StatusLabel
local leaveButton = panel.LeaveButton

local activeModeId = "training"

local function hideQueue()
	gui.Enabled = false
end

local function showQueue()
	gui.Enabled = true
end

local function formatStatus(payload)
	if payload.status == "left" or payload.status == "starting" then
		return nil
	end

	local lines = {}
	if payload.status == "pending" then
		table.insert(lines, payload.message or "Arena belegt — warte...")
	elseif payload.status == "filling" then
		table.insert(
			lines,
			string.format(
				"%s: %d/%d Spieler\nFFA startet in %ds oder bei %d...",
				payload.modeLabel or payload.modeId,
				payload.count or 0,
				payload.max or 0,
				payload.fillTimeout or 12,
				payload.max or 6
			)
		)
	else
		table.insert(
			lines,
			string.format(
				"%s: %d/%d Spieler",
				payload.modeLabel or payload.modeId,
				payload.count or 0,
				payload.max or 0
			)
		)
	end

	if payload.min and payload.max and payload.min == payload.max then
		lines[1] = string.format(
			"%s: %d/%d Spieler",
			payload.modeLabel or payload.modeId,
			payload.count or 0,
			payload.max or 0
		)
	end

	if payload.playerNames and #payload.playerNames > 0 then
		table.insert(lines, "Spieler: " .. table.concat(payload.playerNames, ", "))
	end

	return table.concat(lines, "\n")
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.activeModeId then
		activeModeId = payload.activeModeId
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		hideQueue()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideQueue()
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.status == "left" then
		hideQueue()
		return
	end

	if payload.status == "starting" then
		hideQueue()
		return
	end

	showQueue()
	titleLabel.Text = "Warteschlange — " .. (payload.modeLabel or payload.modeId or "Arena")
	local text = formatStatus(payload)
	statusLabel.Text = text or "Suche Gegner..."
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)

hideQueue()
