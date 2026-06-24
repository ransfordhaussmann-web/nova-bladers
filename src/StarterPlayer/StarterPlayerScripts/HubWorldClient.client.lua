local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.fromOffset(360, 120)
	frame.BackgroundColor3 = Color3.fromRGB(14, 16, 24)
	frame.BackgroundTransparency = 0.1
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 32)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 210, 90)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -20, 1, -44)
	body.Position = UDim2.fromOffset(10, 40)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 16
	body.TextColor3 = Color3.fromRGB(220, 228, 240)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Parent = frame

	hintGui = screen
	return screen
end

local hideToken = 0

local function showHint(payload)
	local gui = ensureHintGui()
	local panel = gui.Panel
	panel.Title.Text = payload.title or "Nova Hub"
	panel.Body.Text = payload.text or ""
	gui.Enabled = true

	hideToken += 1
	local token = hideToken
	task.delay(5, function()
		if hideToken == token then
			gui.Enabled = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

hideBattleUi()
player.CharacterAdded:Connect(function()
	task.defer(hideBattleUi)
end)
