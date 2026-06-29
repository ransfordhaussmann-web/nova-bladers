local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then
	return
end

local zones = hub:WaitForChild("Zones", 10)
local portal = hub:WaitForChild("ArenaPortal", 10)
local portalFrame = portal and portal:FindFirstChild("PortalFrame")
local prompt = portalFrame and portalFrame:FindFirstChild("EnterArenaPrompt")

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubHints"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 5
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "ZoneHint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -24)
hintLabel.Size = UDim2.fromOffset(360, 40)
hintLabel.BackgroundTransparency = 0.3
hintLabel.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
hintLabel.TextColor3 = Color3.fromRGB(220, 230, 255)
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextSize = 15
hintLabel.Text = ""
hintLabel.Visible = false
hintLabel.Parent = hintGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hintLabel

local function getRootPosition()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	return root and root.Position
end

local function isInsideZone(position, zonePart)
	if not zonePart then return false end
	local localPos = zonePart.CFrame:PointToObjectSpace(position)
	local half = zonePart.Size * 0.5
	return math.abs(localPos.X) <= half.X
		and math.abs(localPos.Y) <= half.Y
		and math.abs(localPos.Z) <= half.Z
end

local ZONE_HINTS = {
	ArenaZone = "Arena-Tor — [E] zum Kämpfen",
	BeyKioskZone = "Bey-Auswahl — wähle deinen Kämpfer",
	LeaderboardZone = "Rangliste — Top-Spieler ansehen",
}

local function updateZoneHint()
	if not player:GetAttribute("InHub") then
		hintLabel.Visible = false
		return
	end

	local position = getRootPosition()
	if not position then
		hintLabel.Visible = false
		return
	end

	for zoneName, hintText in ZONE_HINTS do
		local zonePart = zones and zones:FindFirstChild(zoneName)
			or hub:FindFirstChild(zoneName)
		if isInsideZone(position, zonePart) then
			hintLabel.Text = hintText
			hintLabel.Visible = true
			return
		end
	end

	hintLabel.Visible = false
end

if prompt then
	prompt.Triggered:Connect(function()
		if player:GetAttribute("InHub") then
			Remotes.EnterArena:FireServer()
		end
	end)
end

RunService.Heartbeat:Connect(updateZoneHint)

player:GetAttributeChangedSignal("InHub"):Connect(function()
	if not player:GetAttribute("InHub") then
		hintLabel.Visible = false
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
	end
end)
