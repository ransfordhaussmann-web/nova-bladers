local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local queuePanel = panel:FindFirstChild("QueuePanel")
if not queuePanel then
	queuePanel = Instance.new("Frame")
	queuePanel.Name = "QueuePanel"
	queuePanel.Size = UDim2.new(1, -16, 0, 88)
	queuePanel.Position = UDim2.fromOffset(8, 176)
	queuePanel.BackgroundColor3 = Color3.fromRGB(24, 30, 44)
	queuePanel.BackgroundTransparency = 0.1
	queuePanel.BorderSizePixel = 0
	queuePanel.Visible = false
	queuePanel.Parent = panel

	local queueLabel = Instance.new("TextLabel")
	queueLabel.Name = "QueueLabel"
	queueLabel.Size = UDim2.new(1, -12, 1, -36)
	queueLabel.Position = UDim2.fromOffset(6, 4)
	queueLabel.BackgroundTransparency = 1
	queueLabel.Font = Enum.Font.GothamMedium
	queueLabel.TextSize = 12
	queueLabel.TextColor3 = Color3.fromRGB(200, 220, 255)
	queueLabel.TextXAlignment = Enum.TextXAlignment.Left
	queueLabel.TextYAlignment = Enum.TextYAlignment.Top
	queueLabel.Text = ""
	queueLabel.Parent = queuePanel

	local leaveQueueBtn = Instance.new("TextButton")
	leaveQueueBtn.Name = "LeaveQueueButton"
	leaveQueueBtn.Size = UDim2.fromOffset(110, 24)
	leaveQueueBtn.Position = UDim2.new(0, 6, 1, -30)
	leaveQueueBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveQueueBtn.Font = Enum.Font.GothamBold
	leaveQueueBtn.TextSize = 12
	leaveQueueBtn.TextColor3 = Color3.new(1, 1, 1)
	leaveQueueBtn.Text = "Verlassen"
	leaveQueueBtn.Parent = queuePanel
end

local queueLabel = queuePanel:WaitForChild("QueueLabel")
local leaveButton = queuePanel:WaitForChild("LeaveQueueButton")

local function formatQueueText(payload)
	if not payload.inQueue then
		return ""
	end

	local lines = {
		string.format("⏳ Warteschlange: %s", payload.label or payload.mode),
		string.format("%d / %d Spieler", payload.waiting or 0, payload.required or 1),
	}
	if payload.position and payload.position > 0 then
		table.insert(lines, string.format("Deine Position: %d", payload.position))
	end
	if payload.players and #payload.players > 0 then
		table.insert(lines, "Wartend: " .. table.concat(payload.players, ", "))
	end
	return table.concat(lines, "\n")
end

local function setQueueVisible(visible)
	queuePanel.Visible = visible
end

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		queueLabel.Text = formatQueueText(payload)
		setQueueVisible(true)
	else
		queueLabel.Text = ""
		setQueueVisible(false)
	end
end)

leaveButton.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		setQueueVisible(queueLabel.Text ~= "")
	elseif state.phase == "arena" then
		setQueueVisible(false)
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	setQueueVisible(false)
	queueLabel.Text = ""
end)
