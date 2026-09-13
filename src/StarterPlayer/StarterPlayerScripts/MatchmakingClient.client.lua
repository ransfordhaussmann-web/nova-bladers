local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "MatchmakingQueue"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Position = UDim2.new(0.5, 0, 0, 12)
panel.Size = UDim2.fromOffset(320, 96)
panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = panel

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0, 22)
title.Position = UDim2.fromOffset(8, 8)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 15
title.TextColor3 = Color3.fromRGB(120, 180, 255)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Text = "Warteschlange"
title.Parent = panel

local detail = Instance.new("TextLabel")
detail.Name = "Detail"
detail.Size = UDim2.new(1, -16, 0, 36)
detail.Position = UDim2.fromOffset(8, 32)
detail.BackgroundTransparency = 1
detail.Font = Enum.Font.GothamMedium
detail.TextSize = 13
detail.TextColor3 = Color3.new(1, 1, 1)
detail.TextXAlignment = Enum.TextXAlignment.Left
detail.TextYAlignment = Enum.TextYAlignment.Top
detail.TextWrapped = true
detail.Text = ""
detail.Parent = panel

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

local function hideQueue()
	gui.Enabled = false
end

local function showQueue(payload)
	if payload.status == "left" then
		hideQueue()
		return
	end

	if payload.status == "starting" then
		title.Text = payload.modeLabel or "Match"
		detail.Text = payload.detail or "Match startet…"
		leaveBtn.Visible = false
		gui.Enabled = true
		return
	end

	title.Text = string.format("Warteschlange — %s", payload.modeLabel or "Arena")
	detail.Text = payload.detail or string.format("%d Spieler warten", payload.count or 0)
	if payload.status == "pending" then
		detail.TextColor3 = Color3.fromRGB(255, 200, 120)
	else
		detail.TextColor3 = Color3.new(1, 1, 1)
	end
	leaveBtn.Visible = true
	gui.Enabled = true
end

Remotes.QueueUpdate.OnClientEvent:Connect(showQueue)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		leaveBtn.Visible = true
	elseif state.phase == "arena" then
		task.delay(0.5, hideQueue)
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideQueue()
end)

leaveBtn.MouseButton1Click:Connect(function()
	Remotes.QueueLeave:FireServer()
	hideQueue()
end)
