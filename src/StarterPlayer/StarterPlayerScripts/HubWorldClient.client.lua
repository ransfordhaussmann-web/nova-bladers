local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = Instance.new("ScreenGui")
gui.Name = "HubHint"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local frame = Instance.new("Frame")
frame.Size = UDim2.new(0, 320, 0, 56)
frame.Position = UDim2.new(0.5, -160, 0, 16)
frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
frame.BackgroundTransparency = 0.15
frame.BorderSizePixel = 0
frame.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = frame

local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(1, -16, 0.5, 0)
title.Position = UDim2.fromOffset(8, 4)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBold
title.TextSize = 16
title.TextColor3 = Color3.fromRGB(255, 220, 100)
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = frame

local hint = Instance.new("TextLabel")
hint.Name = "Hint"
hint.Size = UDim2.new(1, -16, 0.45, 0)
hint.Position = UDim2.new(0, 8, 0.5, 0)
hint.BackgroundTransparency = 1
hint.Font = Enum.Font.Gotham
hint.TextSize = 14
hint.TextColor3 = Color3.fromRGB(210, 210, 220)
hint.TextXAlignment = Enum.TextXAlignment.Left
hint.Parent = frame

local hideToken = 0

local function showHint(zoneName, zoneHint)
	hideToken += 1
	local token = hideToken
	title.Text = zoneName or ""
	hint.Text = zoneHint or ""
	gui.Enabled = true
	task.delay(4, function()
		if hideToken == token then
			gui.Enabled = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	showHint("Willkommen zurück", "Erkunde den Nova Hub")
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.HubZoneAction.OnClientEvent:Connect(function(_zoneId, action)
	if action == "EnterArena" then
		gui.Enabled = false
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
		local hud = player.PlayerGui:FindFirstChild("BattleHUD")
		if hud then hud.Enabled = true end
		local mobile = player.PlayerGui:FindFirstChild("MobileControls")
		if mobile then mobile.Enabled = true end
	end
end)
