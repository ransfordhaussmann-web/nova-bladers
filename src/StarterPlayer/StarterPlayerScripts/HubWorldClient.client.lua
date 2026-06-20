local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil
local promptGui

local function getZonesFolder()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then return nil end
	return hub:WaitForChild("Zones", 10)
end

local function createPrompt()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HubZonePrompt"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Hint"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0.92, 0)
	label.Size = UDim2.fromOffset(400, 40)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 16
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

local function setPromptVisible(visible, hint)
	if not promptGui then return end
	promptGui.Enabled = visible
	if visible and hint then
		promptGui.Hint.Text = hint
	end
end

local function findNearestZone()
	local character = player.Character
	if not character then return nil end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end

	local zonesFolder = getZonesFolder()
	if not zonesFolder then return nil end

	local nearest, nearestDist = nil, math.huge
	for _, zonePart in zonesFolder:GetChildren() do
		if zonePart:IsA("BasePart") then
			local dist = (zonePart.Position - root.Position).Magnitude
			local reach = math.max(zonePart.Size.X, zonePart.Size.Z) * 0.5 + 2
			if dist <= reach and dist < nearestDist then
				nearest = zonePart
				nearestDist = dist
			end
		end
	end
	return nearest
end

local function onZoneAction()
	if not activeZone then return end
	local action = activeZone:GetAttribute("ZoneAction")
	if action then
		Remotes.HubZoneAction:FireServer(action)
	end
end

promptGui = createPrompt()

task.spawn(function()
	while true do
		local zone = findNearestZone()
		if zone ~= activeZone then
			activeZone = zone
			if activeZone then
				setPromptVisible(true, activeZone:GetAttribute("ZoneHint") or "Drücke E")
			else
				setPromptVisible(false)
			end
		end
		task.wait(0.15)
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.E then
		onZoneAction()
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
