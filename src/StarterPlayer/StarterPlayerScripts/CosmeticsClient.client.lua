local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "Cosmetics"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.fromOffset(320, 300)
frame.Position = UDim2.new(1, -332, 0, 12)
frame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Size = UDim2.new(1, 0, 0, 36)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "Cosmetics"
title.Parent = frame

local closeBtn = Instance.new("TextButton")
closeBtn.Size = UDim2.fromOffset(28, 28)
closeBtn.Position = UDim2.new(1, -34, 0, 4)
closeBtn.BackgroundTransparency = 1
closeBtn.Font = Enum.Font.GothamBold
closeBtn.TextSize = 18
closeBtn.TextColor3 = Color3.fromRGB(180, 190, 210)
closeBtn.Text = "×"
closeBtn.Parent = frame
closeBtn.MouseButton1Click:Connect(function()
	gui.Enabled = false
end)

local trailLabel = Instance.new("TextLabel")
trailLabel.Size = UDim2.new(1, -16, 0, 20)
trailLabel.Position = UDim2.fromOffset(8, 40)
trailLabel.BackgroundTransparency = 1
trailLabel.Font = Enum.Font.GothamMedium
trailLabel.TextSize = 13
trailLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
trailLabel.TextXAlignment = Enum.TextXAlignment.Left
trailLabel.Text = "Speed Trail"
trailLabel.Parent = frame

local trailList = Instance.new("Frame")
trailList.Name = "TrailList"
trailList.Size = UDim2.new(1, -16, 0, 88)
trailList.Position = UDim2.fromOffset(8, 62)
trailList.BackgroundTransparency = 1
trailList.Parent = frame

local trailLayout = Instance.new("UIListLayout")
trailLayout.Padding = UDim.new(0, 6)
trailLayout.FillDirection = Enum.FillDirection.Horizontal
trailLayout.Parent = trailList

local skinLabel = Instance.new("TextLabel")
skinLabel.Size = UDim2.new(1, -16, 0, 20)
skinLabel.Position = UDim2.fromOffset(8, 158)
skinLabel.BackgroundTransparency = 1
skinLabel.Font = Enum.Font.GothamMedium
skinLabel.TextSize = 13
skinLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
skinLabel.TextXAlignment = Enum.TextXAlignment.Left
skinLabel.Text = "Arena Skin"
skinLabel.Parent = frame

local skinList = Instance.new("Frame")
skinList.Name = "SkinList"
skinList.Size = UDim2.new(1, -16, 0, 88)
skinList.Position = UDim2.fromOffset(8, 180)
skinList.BackgroundTransparency = 1
skinList.Parent = frame

local skinLayout = Instance.new("UIListLayout")
skinLayout.Padding = UDim.new(0, 6)
skinLayout.FillDirection = Enum.FillDirection.Horizontal
skinLayout.Parent = skinList

local selectedTrail = "Nova"
local selectedSkin = "Midnight"

local function clearButtons(parent)
	for _, child in parent:GetChildren() do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
end

local function makeOptionButton(parent, label, color, isSelected, onClick)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.fromOffset(68, 36)
	btn.BackgroundColor3 = isSelected and Color3.fromRGB(50, 60, 85) or Color3.fromRGB(30, 36, 52)
	btn.BorderSizePixel = 0
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = Color3.new(1, 1, 1)
	btn.Text = label
	btn.Parent = parent

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = btn

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(1, 0, 0, 3)
	accent.Position = UDim2.new(0, 0, 1, -3)
	accent.BackgroundColor3 = color
	accent.BorderSizePixel = 0
	accent.Parent = btn

	btn.MouseButton1Click:Connect(onClick)
	return btn
end

local function refreshUI(catalog)
	clearButtons(trailList)
	clearButtons(skinList)

	for _, trail in catalog.trails do
		makeOptionButton(trailList, trail.name, trail.color, trail.id == selectedTrail, function()
			selectedTrail = trail.id
			Remotes.CosmeticsSelect:FireServer({ trailId = trail.id })
		end)
	end

	for _, skin in catalog.arenaSkins do
		makeOptionButton(skinList, skin.name, skin.rim, skin.id == selectedSkin, function()
			selectedSkin = skin.id
			Remotes.CosmeticsSelect:FireServer({ arenaSkin = skin.id })
		end)
	end
end

Remotes.CosmeticsUpdate.OnClientEvent:Connect(function(payload)
	selectedTrail = payload.trailId or selectedTrail
	selectedSkin = payload.arenaSkin or selectedSkin
	if payload.catalog then
		refreshUI(payload.catalog)
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		gui.Enabled = true
	elseif state.phase == "arena" or state.phase == "queue" then
		gui.Enabled = false
	end
end)

-- Toggle from lobby panel
task.defer(function()
	local lobby = player.PlayerGui:WaitForChild("Lobby", 10)
	if not lobby then
		return
	end
	local panel = lobby:WaitForChild("Panel", 5)
	if not panel then
		return
	end

	local cosmeticsBtn = Instance.new("TextButton")
	cosmeticsBtn.Name = "CosmeticsButton"
	cosmeticsBtn.Size = UDim2.fromOffset(120, 28)
	cosmeticsBtn.Position = UDim2.fromOffset(136, 100)
	cosmeticsBtn.BackgroundColor3 = Color3.fromRGB(70, 55, 95)
	cosmeticsBtn.Font = Enum.Font.GothamBold
	cosmeticsBtn.TextSize = 12
	cosmeticsBtn.TextColor3 = Color3.new(1, 1, 1)
	cosmeticsBtn.Text = "Cosmetics"
	cosmeticsBtn.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = cosmeticsBtn

	cosmeticsBtn.MouseButton1Click:Connect(function()
		gui.Enabled = not gui.Enabled
	end)
end)
