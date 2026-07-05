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

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "List"
scroll.Size = UDim2.new(1, -20, 1, -80)
scroll.Position = UDim2.fromOffset(10, 72)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 6
scroll.ScrollBarImageColor3 = Color3.fromRGB(80, 90, 120)
scroll.CanvasSize = UDim2.fromOffset(0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = frame

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = scroll

local selectedId = nil

local function clearList()
	for _, child in scroll:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function createBeyButton(bey)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -8, 0, 56)
	btn.BackgroundColor3 = Color3.fromRGB(30, 36, 52)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 0
	btn.Text = ""
	btn.Parent = scroll

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 8)
	btnCorner.Parent = btn

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 4, 1, 0)
	accent.BackgroundColor3 = bey.color
	accent.BorderSizePixel = 0
	accent.Parent = btn

	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, -12, 0, 22)
	nameLabel.Position = UDim2.fromOffset(12, 8)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.TextColor3 = Color3.new(1, 1, 1)
	local storeTag = bey.storeItem and "  [Store]" or ""
	nameLabel.Text = bey.name .. storeTag
	nameLabel.Parent = btn

	local detailLabel = Instance.new("TextLabel")
	detailLabel.Size = UDim2.new(1, -12, 0, 18)
	detailLabel.Position = UDim2.fromOffset(12, 30)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = Enum.Font.GothamMedium
	detailLabel.TextSize = 12
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.TextColor3 = Color3.fromRGB(160, 170, 195)
	detailLabel.Text = ("%s  ·  %s"):format(bey.beyType, bey.special or "")
	detailLabel.Parent = btn

	if bey.storeItem then
		local badge = Instance.new("TextLabel")
		badge.Size = UDim2.fromOffset(52, 18)
		badge.Position = UDim2.new(1, -60, 0, 8)
		badge.BackgroundColor3 = Color3.fromRGB(255, 180, 50)
		badge.Font = Enum.Font.GothamBold
		badge.TextSize = 10
		badge.TextColor3 = Color3.fromRGB(30, 20, 5)
		badge.Text = "STORE"
		badge.Parent = btn

		local badgeCorner = Instance.new("UICorner")
		badgeCorner.CornerRadius = UDim.new(0, 4)
		badgeCorner.Parent = badge
	end

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
