local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local function ensureQueueUi()
	local queueLabel = panel:FindFirstChild("QueueLabel")
	if not queueLabel then
		queueLabel = Instance.new("TextLabel")
		queueLabel.Name = "QueueLabel"
		queueLabel.Size = UDim2.new(1, -16, 0, 36)
		queueLabel.Position = UDim2.fromOffset(8, 100)
		queueLabel.BackgroundTransparency = 1
		queueLabel.Font = Enum.Font.GothamMedium
		queueLabel.TextSize = 12
		queueLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
		queueLabel.TextXAlignment = Enum.TextXAlignment.Left
		queueLabel.TextYAlignment = Enum.TextYAlignment.Top
		queueLabel.Text = ""
		queueLabel.Visible = false
		queueLabel.Parent = panel
	end

	local leaveQueueBtn = panel:FindFirstChild("LeaveQueueButton")
	if not leaveQueueBtn then
		leaveQueueBtn = Instance.new("TextButton")
		leaveQueueBtn.Name = "LeaveQueueButton"
		leaveQueueBtn.Size = UDim2.fromOffset(120, 28)
		leaveQueueBtn.Position = UDim2.fromOffset(8, 140)
		leaveQueueBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
		leaveQueueBtn.Font = Enum.Font.GothamBold
		leaveQueueBtn.TextSize = 13
		leaveQueueBtn.TextColor3 = Color3.new(1, 1, 1)
		leaveQueueBtn.Text = "Verlassen"
		leaveQueueBtn.Visible = false
		leaveQueueBtn.Parent = panel

		local leaveCorner = Instance.new("UICorner")
		leaveCorner.CornerRadius = UDim.new(0, 6)
		leaveCorner.Parent = leaveQueueBtn
	end

	return queueLabel, leaveQueueBtn
end

local queueLabel, leaveQueueBtn = ensureQueueUi()
local startButton = panel:WaitForChild("StartButton")

local function setQueueVisible(visible)
	queueLabel.Visible = visible
	leaveQueueBtn.Visible = visible
	startButton.Visible = not visible
end

local function applyQueueState(payload)
	if payload.inQueue then
		setQueueVisible(true)
		queueLabel.Text = string.format(
			"Warteschlange: %s\nSpieler: %d / %d",
			payload.modeLabel or payload.modeId or "?",
			payload.waiting or 0,
			payload.needed or 0
		)
	else
		setQueueVisible(false)
		queueLabel.Text = ""
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueState)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "queuing" then
		gui.Enabled = true
	elseif state.phase == "arena" then
		setQueueVisible(false)
	end
end)

leaveQueueBtn.MouseButton1Click:Connect(function()
	Remotes.LeaveMatchQueue:FireServer()
end)

applyQueueState({ inQueue = false })
