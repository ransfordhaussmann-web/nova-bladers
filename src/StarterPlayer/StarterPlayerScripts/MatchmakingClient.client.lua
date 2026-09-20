local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local playerGui = player:WaitForChild("PlayerGui")

local function getQueueGui()
	local gui = playerGui:FindFirstChild("MatchmakingQueue")
	if gui then
		return gui
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MatchmakingQueue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 12)
	panel.Size = UDim2.fromOffset(320, 118)
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
	title.TextSize = 15
	title.TextColor3 = Color3.fromRGB(120, 180, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Warteschlange"
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.Size = UDim2.new(1, -16, 0, 52)
	status.Position = UDim2.fromOffset(8, 34)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.GothamMedium
	status.TextSize = 13
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

	leaveBtn.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
	end)

	return gui
end

local function statusText(payload)
	if payload.status == "pending" then
		return string.format(
			"%s\nArena belegt — du bist als Nächstes dran.\nSpieler: %d / %d",
			payload.modeLabel,
			payload.playersInQueue,
			payload.maxPlayers
		)
	end

	if payload.fillTimeRemaining and payload.fillTimeRemaining > 0 then
		return string.format(
			"%s\nWarte auf Spieler… %d / %d (Start in %ds)",
			payload.modeLabel,
			payload.playersInQueue,
			payload.maxPlayers,
			math.ceil(payload.fillTimeRemaining)
		)
	end

	if payload.status == "starting" then
		return string.format("%s\nMatch startet gleich…", payload.modeLabel)
	end

	return string.format(
		"%s\nWarte auf Spieler… %d / %d",
		payload.modeLabel,
		payload.playersInQueue,
		payload.maxPlayers
	)
end

local function applyQueueUpdate(payload)
	local gui = getQueueGui()
	local panel = gui.Panel

	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	panel.Title.Text = payload.arenaBusy and "Warteschlange (Pending)" or "Warteschlange"
	panel.Status.Text = statusText(payload)
	gui.Enabled = true
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueUpdate)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		local gui = playerGui:FindFirstChild("MatchmakingQueue")
		if gui then
			gui.Enabled = false
		end
	end
end)
