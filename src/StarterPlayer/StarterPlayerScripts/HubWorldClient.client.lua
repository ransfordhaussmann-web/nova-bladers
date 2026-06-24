local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local HINT_DISTANCE = 14

local gui = Instance.new("ScreenGui")
gui.Name = "HubHUD"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local statsFrame = Instance.new("Frame")
statsFrame.Name = "StatsPanel"
statsFrame.AnchorPoint = Vector2.new(0, 0)
statsFrame.Position = UDim2.fromOffset(16, 16)
statsFrame.Size = UDim2.fromOffset(200, 90)
statsFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
statsFrame.BackgroundTransparency = 0.25
statsFrame.Parent = gui

local statsCorner = Instance.new("UICorner")
statsCorner.CornerRadius = UDim.new(0, 10)
statsCorner.Parent = statsFrame

local statsLabel = Instance.new("TextLabel")
statsLabel.Name = "StatsLabel"
statsLabel.Size = UDim2.new(1, -16, 1, -16)
statsLabel.Position = UDim2.fromOffset(8, 8)
statsLabel.BackgroundTransparency = 1
statsLabel.TextColor3 = Color3.new(1, 1, 1)
statsLabel.Font = Enum.Font.Gotham
statsLabel.TextSize = 16
statsLabel.TextXAlignment = Enum.TextXAlignment.Left
statsLabel.TextYAlignment = Enum.TextYAlignment.Top
statsLabel.Text = "Nova Hub"
statsLabel.Parent = statsFrame

local hintFrame = Instance.new("Frame")
hintFrame.Name = "ZoneHint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(420, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.2
hintFrame.Visible = false
hintFrame.Parent = gui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 12)
hintCorner.Parent = hintFrame

local hintTitle = Instance.new("TextLabel")
hintTitle.Name = "Title"
hintTitle.Size = UDim2.new(1, -20, 0, 22)
hintTitle.Position = UDim2.fromOffset(10, 6)
hintTitle.BackgroundTransparency = 1
hintTitle.Font = Enum.Font.GothamBold
hintTitle.TextSize = 16
hintTitle.TextColor3 = Color3.fromRGB(255, 220, 100)
hintTitle.TextXAlignment = Enum.TextXAlignment.Left
hintTitle.Parent = hintFrame

local hintText = Instance.new("TextLabel")
hintText.Name = "Text"
hintText.Size = UDim2.new(1, -20, 0, 22)
hintText.Position = UDim2.fromOffset(10, 28)
hintText.BackgroundTransparency = 1
hintText.Font = Enum.Font.Gotham
hintText.TextSize = 14
hintText.TextColor3 = Color3.new(1, 1, 1)
hintText.TextXAlignment = Enum.TextXAlignment.Left
hintText.Parent = hintFrame

local inHub = true
local lastZoneId

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function showHint(title, text)
	hintTitle.Text = title or ""
	hintText.Text = text or ""
	hintFrame.Visible = title ~= nil and text ~= nil
end

local function getZoneParts()
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return {} end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return {} end
	return zones:GetChildren()
end

local function updateNearestZone()
	if not inHub then
		showHint(nil, nil)
		return
	end

	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local nearest
	local nearestDist = HINT_DISTANCE

	for _, zonePart in getZoneParts() do
		if zonePart:IsA("BasePart") then
			local dist = (zonePart.Position - hrp.Position).Magnitude
			if dist < nearestDist then
				nearestDist = dist
				nearest = zonePart
			end
		end
	end

	if nearest then
		local zoneId = nearest:GetAttribute("ZoneId") or nearest.Name
		if zoneId ~= lastZoneId then
			lastZoneId = zoneId
		end
		showHint(nearest:GetAttribute("ZoneName") or nearest.Name, nearest:GetAttribute("ZoneHint"))
	else
		lastZoneId = nil
		showHint(nil, nil)
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		inHub = true
		hideBattleUi()
		gui.Enabled = true
		statsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nPkt.: %d\n%s",
			payload.wins,
			payload.losses,
			payload.rank,
			payload.modeLabel or ""
		)
	else
		inHub = false
		gui.Enabled = false
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.visible == false then
		showHint(nil, nil)
		return
	end
	showHint(payload.title, payload.text)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

RunService.Heartbeat:Connect(updateNearestZone)

hideBattleUi()
gui.Enabled = true
