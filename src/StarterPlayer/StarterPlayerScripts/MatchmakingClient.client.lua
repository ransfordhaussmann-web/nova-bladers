local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Matchmaking"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
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

local status = Instance.new("TextLabel")
status.Name = "Status"
status.Size = UDim2.new(1, -16, 0, 40)
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
leaveBtn.Position = UDim2.fromOffset(8, 82)
leaveBtn.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
leaveBtn.Font = Enum.Font.GothamBold
leaveBtn.TextSize = 13
leaveBtn.TextColor3 = Color3.new(1, 1, 1)
leaveBtn.Text = "Queue verlassen"
leaveBtn.Parent = panel

local btnCorner = Instance.new("UICorner")
btnCorner.CornerRadius = UDim.new(0, 6)
btnCorner.Parent = leaveBtn

local function formatStatus(payload)
	if not payload.inQueue then
		return ""
	end

	local lines = { payload.modeLabel or payload.modeId or "Queue" }

	if payload.status == "pending" then
		table.insert(lines, payload.message or "Arena belegt — warte...")
	elseif payload.status == "starting" then
		table.insert(lines, "Match startet...")
	elseif payload.modeId == "ffa" and payload.fillRemaining then
		table.insert(
			lines,
			string.format(
				"%d/%d Spieler — Start in %ds",
				payload.queued or 0,
				payload.maxPlayers or payload.needed or 0,
				payload.fillRemaining
			)
		)
	else
		table.insert(
			lines,
			string.format(
				"%d/%d Spieler",
				payload.queued or payload.position or 0,
				payload.needed or 0
			)
		)
	end

	if payload.message and payload.message ~= "" and payload.status ~= "pending" then
		table.insert(lines, payload.message)
	end

	return table.concat(lines, "\n")
end

local function applyQueueState(payload)
	if not payload.inQueue then
		gui.Enabled = false
		return
	end

	gui.Enabled = true
	title.Text = "In Queue: " .. (payload.modeLabel or payload.modeId or "?")
	status.Text = formatStatus(payload)

	if payload.status == "starting" then
		leaveBtn.Visible = false
	else
		leaveBtn.Visible = true
	end
end

Remotes.QueueUpdate.OnClientEvent:Connect(applyQueueState)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	gui.Enabled = false
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" then
		gui.Enabled = false
	end
end)
