local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local gui = player:WaitForChild("PlayerGui"):FindFirstChild("Lobby")
local promptGui = Instance.new("ScreenGui")
promptGui.Name = "HubPrompt"
promptGui.ResetOnSpawn = false
promptGui.DisplayOrder = 10
promptGui.Parent = player.PlayerGui

local promptLabel = Instance.new("TextLabel")
promptLabel.Name = "Prompt"
promptLabel.AnchorPoint = Vector2.new(0.5, 1)
promptLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
promptLabel.Size = UDim2.fromOffset(360, 40)
promptLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
promptLabel.BackgroundTransparency = 0.25
promptLabel.BorderSizePixel = 0
promptLabel.Font = Enum.Font.GothamMedium
promptLabel.TextSize = 16
promptLabel.TextColor3 = Color3.new(1, 1, 1)
promptLabel.Visible = false
promptLabel.Parent = promptGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = promptLabel

local activeZoneId = nil

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function hideLobby()
	if gui then
		gui.Enabled = false
	end
end

local function getCharacterPosition()
	local character = player.Character
	if not character then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return nil
	end
	return root.Position
end

local function findNearestZone()
	local position = getCharacterPosition()
	if not position then
		return nil
	end

	local bestId = nil
	local bestDist = math.huge
	for zoneId, zone in HubConfig.ZONES do
		local flat = Vector3.new(position.X, zone.position.Y, position.Z)
		local dist = (flat - zone.position).Magnitude
		if dist <= zone.radius and dist < bestDist then
			bestDist = dist
			bestId = zoneId
		end
	end
	return bestId
end

local function updatePrompt()
	local zoneId = findNearestZone()
	activeZoneId = zoneId
	if zoneId then
		local zone = HubConfig.ZONES[zoneId]
		promptLabel.Text = string.format("[E] %s", zone.prompt)
		promptLabel.Visible = true
	else
		promptLabel.Visible = false
	end
end

local function onInteract()
	if not activeZoneId then
		return
	end
	Remotes.HubZoneAction:FireServer(activeZoneId)
end

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	hideLobby()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
end)

Remotes.ShowHallPanel.OnClientEvent:Connect(function()
	if gui then
		gui.Enabled = true
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideLobby()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	hideLobby()
	promptLabel.Visible = false
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.E then
		onInteract()
	end
end)

if gui then
	gui.Enabled = false
end
hideBattleUi()

RunService.Heartbeat:Connect(updatePrompt)
