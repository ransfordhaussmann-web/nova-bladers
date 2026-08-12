local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil
local hintGui

local function getOrCreateHintGui()
	if hintGui then
		return hintGui
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 24)
	frame.Size = UDim2.fromOffset(360, 56)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 6)
	title.Size = UDim2.new(1, -24, 0, 22)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.fromRGB(120, 200, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(12, 28)
	hint.Size = UDim2.new(1, -24, 0, 20)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	hintGui = screen
	return screen
end

local function showZoneHint(payload)
	local gui = getOrCreateHintGui()
	local banner = gui.Banner
	banner.Title.Text = payload.name or "Zone"
	banner.Hint.Text = payload.hint or ""
	banner.Visible = true
	activeZone = payload
	task.delay(3, function()
		if activeZone == payload then
			banner.Visible = false
			activeZone = nil
		end
	end)
end

local function tryZoneAction()
	if not activeZone or not activeZone.action then
		return
	end
	if activeZone.action == "EnterArena" then
		Remotes.EnterArena:FireServer()
	elseif activeZone.action == "OpenBeySelect" then
		Remotes.OpenBeySelect:FireServer()
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)
