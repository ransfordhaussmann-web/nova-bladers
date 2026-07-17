local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "BeySelect"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(420, 400)
frame.Position = UDim2.new(0.5, -210, 0.5, -200)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 12)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 40)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 20
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Wähle deinen Bey"
title.Parent = frame

local timerLabel = Instance.new("TextLabel")
timerLabel.Name = "Timer"
timerLabel.Size = UDim2.new(1, -20, 0, 24)
timerLabel.Position = UDim2.fromOffset(10, 44)
timerLabel.BackgroundTransparency = 1
timerLabel.Font = Enum.Font.GothamMedium
timerLabel.TextSize = 14
timerLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
timerLabel.Text = ""
timerLabel.Parent = frame

local list = Instance.new("ScrollingFrame")
list.Name = "List"
list.Size = UDim2.new(1, -20, 1, -80)
list.Position = UDim2.fromOffset(10, 72)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 6
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = list

local selectedId = nil

local function clearList()
	for _, child in list:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function createBeyButton(bey)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 48)
	btn.BackgroundColor3 = Color3.fromRGB(30, 36, 52)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 15
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.Text = ("  %s  —  %s"):format(bey.name, bey.beyType)
	btn.Parent = list

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.BackgroundColor3 = bey.color
	accent.BorderSizePixel = 0
	accent.Parent = btn

	btn.MouseButton1Click:Connect(function()
		selectedId = bey.id
		Remotes.BeySelectPick:FireServer(bey.id)
		gui.Enabled = false
	end)

	return btn
end

Remotes.BeySelectStart.OnClientEvent:Connect(function(payload)
	clearList()
	selectedId = nil
	gui.Enabled = true

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end

	for _, bey in payload.catalog do
		createBeyButton(bey)
	end

	local remaining = payload.timeout or 20
	timerLabel.Text = ("Zeit: %ds"):format(remaining)
	task.spawn(function()
		while remaining > 0 and gui.Enabled do
			task.wait(1)
			remaining -= 1
			timerLabel.Text = ("Zeit: %ds"):format(remaining)
		end
	end)
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase ~= "Selecting" then
		gui.Enabled = false
	end
end)
