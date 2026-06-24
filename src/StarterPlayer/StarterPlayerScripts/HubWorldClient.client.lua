local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubHint"
	screen.ResetOnSpawn = false
	screen.Enabled = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Banner"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.fromOffset(360, 56)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 34)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0.5, 0)
	title.Position = UDim2.fromOffset(10, 6)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 18
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -20, 0.5, 0)
	hint.Position = UDim2.fromOffset(10, 28)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(180, 190, 210)
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	hintGui = screen
	return screen
end

local function showHint(payload)
	local gui = ensureHintGui()
	gui.Banner.Title.Text = payload.title or "Hub"
	gui.Banner.Hint.Text = payload.hint or ""
	gui.Enabled = true
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	showHint(payload)
	task.delay(4, function()
		if hintGui then
			hintGui.Enabled = false
		end
	end)
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
	if hintGui then
		hintGui.Enabled = false
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	else
		showHint({
			title = "Bey-Labor",
			hint = "BeySelect-GUI in Studio verknüpfen",
		})
	end
end)
