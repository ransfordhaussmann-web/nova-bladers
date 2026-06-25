local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local currentZone = nil
local lastCheck = 0

local promptGui = Instance.new("ScreenGui")
promptGui.Name = "HubPrompt"
promptGui.ResetOnSpawn = false
promptGui.DisplayOrder = 10
promptGui.Parent = playerGui

local promptFrame = Instance.new("Frame")
promptFrame.Name = "Prompt"
promptFrame.AnchorPoint = Vector2.new(0.5, 1)
promptFrame.Position = UDim2.new(0.5, 0, 1, -80)
promptFrame.Size = UDim2.fromOffset(320, 48)
promptFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
promptFrame.BackgroundTransparency = 0.15
promptFrame.BorderSizePixel = 0
promptFrame.Visible = false
promptFrame.Parent = promptGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = promptFrame

local promptLabel = Instance.new("TextLabel")
promptLabel.Size = UDim2.fromScale(1, 1)
promptLabel.BackgroundTransparency = 1
promptLabel.Font = Enum.Font.GothamBold
promptLabel.TextColor3 = Color3.new(1, 1, 1)
promptLabel.TextSize = 18
promptLabel.Text = ""
promptLabel.Parent = promptFrame

local function getCharacterPosition()
	local character = player.Character
	if not character then return nil end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return nil end
	return hrp.Position
end

local function findZoneAt(position)
	for _, zone in HubConfig.ZONES do
		local flat = Vector3.new(position.X, zone.position.Y, position.Z)
		local zoneFlat = Vector3.new(zone.position.X, zone.position.Y, zone.position.Z)
		if (flat - zoneFlat).Magnitude <= zone.radius then
			return zone
		end
	end
	return nil
end

local function setPrompt(zone)
	if zone then
		promptLabel.Text = zone.prompt
		promptFrame.Visible = true
	else
		promptFrame.Visible = false
	end
end

local function interact()
	if not currentZone then return end
	Remotes.HubInteract:FireServer(currentZone.id)

	if currentZone.id == "BeyTerminal" then
		local select = playerGui:FindFirstChild("BeySelect")
		if select then
			select.Enabled = true
		end
	elseif currentZone.id == "ArenaGate" then
		local lobby = playerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = false
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		interact()
	end
end)

RunService.Heartbeat:Connect(function()
	local now = tick()
	if now - lastCheck < HubConfig.PROXIMITY_CHECK_INTERVAL then return end
	lastCheck = now

	local pos = getCharacterPosition()
	if not pos then
		currentZone = nil
		setPrompt(nil)
		return
	end

	local zone = findZoneAt(pos)
	if zone ~= currentZone then
		if currentZone and currentZone.id == "StatsBoard" then
			player:SetAttribute("NovaBladers_ShowStatsPanel", false)
			local lobby = playerGui:FindFirstChild("Lobby")
			if lobby then lobby.Enabled = false end
		end
		currentZone = zone
		setPrompt(zone)
	end
end)
