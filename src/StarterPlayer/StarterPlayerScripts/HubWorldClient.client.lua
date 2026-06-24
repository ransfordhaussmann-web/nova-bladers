local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil
local currentAction = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Size = UDim2.new(0, 320, 0, 72)
hintFrame.Position = UDim2.new(0.5, -160, 0.85, 0)
hintFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Size = UDim2.new(1, -16, 0.55, 0)
hintLabel.Position = UDim2.fromOffset(8, 6)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextScaled = true
hintLabel.Font = Enum.Font.GothamBold
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local actionLabel = Instance.new("TextLabel")
actionLabel.Size = UDim2.new(1, -16, 0.35, 0)
actionLabel.Position = UDim2.new(0, 8, 0.58, 0)
actionLabel.BackgroundTransparency = 1
actionLabel.TextColor3 = Color3.fromRGB(180, 200, 255)
actionLabel.TextScaled = true
actionLabel.Font = Enum.Font.Gotham
actionLabel.Text = "[E] Interagieren"
actionLabel.Parent = hintFrame

local statsGui = Instance.new("ScreenGui")
statsGui.Name = "HubStats"
statsGui.ResetOnSpawn = false
statsGui.Enabled = false
statsGui.Parent = player.PlayerGui

local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(0, 200, 0, 90)
statsFrame.Position = UDim2.new(0, 12, 0, 12)
statsFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
statsFrame.BackgroundTransparency = 0.2
statsFrame.BorderSizePixel = 0
statsFrame.Parent = statsGui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 8)
statsCorner.Parent = statsFrame

local statsLabel = Instance.new("TextLabel")
statsLabel.Size = UDim2.new(1, -12, 1, -12)
statsLabel.Position = UDim2.fromOffset(6, 6)
statsLabel.BackgroundTransparency = 1
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.TextColor3 = Color3.fromRGB(220, 225, 240)
statsLabel.TextSize = 16
statsLabel.Font = Enum.Font.Gotham
statsLabel.Text = ""
statsLabel.Parent = statsFrame

local function hideBattleUI()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function checkZones()
	local hrp = getCharacterRoot()
	if not hrp then
		currentZone = nil
		currentAction = nil
		hintGui.Enabled = false
		return
	end

	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	local nearest = nil
	local nearestDist = math.huge

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local dist = (hrp.Position - zonePart.Position).Magnitude
			local reach = math.max(zonePart.Size.X, zonePart.Size.Z) / 2 + 4
			if dist < reach and dist < nearestDist then
				nearest = zonePart
				nearestDist = dist
			end
		end
	end

	if nearest then
		currentZone = nearest:GetAttribute("ZoneName") or nearest.Name
		currentAction = nearest:GetAttribute("ZoneAction")
		hintLabel.Text = nearest:GetAttribute("ZoneHint") or currentZone
		hintGui.Enabled = true
	else
		currentZone = nil
		currentAction = nil
		hintGui.Enabled = false
	end
end

RunService.Heartbeat:Connect(checkZones)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E and currentAction then
		Remotes.HubZoneAction:FireServer(currentAction)
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(hint)
	hintLabel.Text = hint or ""
	hintGui.Enabled = hint ~= nil and hint ~= ""
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if not payload.inHub then return end
	hideBattleUI()

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end

	statsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d\n%s",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0,
		payload.modeLabel or ""
	)
	statsGui.Enabled = true
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	statsGui.Enabled = true
	hideBattleUI()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end)
