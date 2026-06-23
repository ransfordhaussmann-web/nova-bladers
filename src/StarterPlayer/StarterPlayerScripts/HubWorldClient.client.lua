local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local currentZone = nil
local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "HintFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.new(0, 420, 0, 56)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Font = Enum.Font.GothamMedium
	label.Parent = frame

	hintGui = screen
	return screen
end

local function showHint(text)
	local gui = ensureHintGui()
	local frame = gui.HintFrame
	frame.HintLabel.Text = text or ""
	frame.Visible = text ~= nil and text ~= ""
end

local function hideHint()
	if hintGui then
		hintGui.HintFrame.Visible = false
	end
end

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findZoneAtPosition(position)
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end

	for _, trigger in zones:GetChildren() do
		if trigger:IsA("BasePart") then
			local localPos = trigger.CFrame:PointToObjectSpace(position)
			local half = trigger.Size * 0.5
			if math.abs(localPos.X) <= half.X
				and math.abs(localPos.Y) <= half.Y
				and math.abs(localPos.Z) <= half.Z
			then
				return trigger
			end
		end
	end
	return nil
end

local function updateZone()
	if not inHub then
		hideHint()
		currentZone = nil
		return
	end

	local root = getCharacterRoot()
	if not root then return end

	local zone = findZoneAtPosition(root.Position)
	if zone == currentZone then return end
	currentZone = zone

	if zone then
		local hint = zone:GetAttribute("ZoneHint") or zone:GetAttribute("ZoneName") or ""
		local action = zone:GetAttribute("ZoneAction")
		if action and action ~= "" then
			hint = hint .. "\n[E] Interagieren"
		end
		showHint(hint)
		Remotes.HubZoneHint:FireServer(zone:GetAttribute("ZoneId"))
	else
		hideHint()
		Remotes.HubZoneHint:FireServer(nil)
	end
end

local function tryZoneAction()
	if not inHub or not currentZone then return end
	local action = currentZone:GetAttribute("ZoneAction")
	if action and action ~= "" then
		Remotes.HubZoneAction:FireServer(action)
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		hideHint()
		currentZone = nil
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(_payload)
	-- Server echo optional; local detection drives hints
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		tryZoneAction()
	end
end)

task.spawn(function()
	while true do
		updateZone()
		task.wait(0.15)
	end
end)
