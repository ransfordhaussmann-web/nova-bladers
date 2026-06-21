local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local currentZone = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubHints"
screenGui.ResetOnSpawn = false
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "ZoneHint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.new(0, 420, 0, 44)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
hintLabel.TextSize = 20
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.Text = ""
hintLabel.Visible = false
hintLabel.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findNearestZone()
	local root = getCharacterRoot()
	if not root then return nil end

	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end

	local bestZone = nil
	local bestDist = HubConfig.INTERACT_DISTANCE

	for _, child in hub:GetChildren() do
		local zoneId = child:GetAttribute("ZoneId")
		if zoneId then
			local dist = (root.Position - child.Position).Magnitude
			if dist < bestDist then
				bestDist = dist
				bestZone = child
			end
		end
	end

	return bestZone
end

local function showHint(text)
	if text and text ~= "" then
		hintLabel.Text = text
		hintLabel.Visible = true
	else
		hintLabel.Visible = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub ~= nil then
		inHub = payload.inHub
	end
	if not inHub then
		showHint("")
		currentZone = nil
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not currentZone then return end

	local zoneId = currentZone:GetAttribute("ZoneId")
	if zoneId == "ArenaGate" then
		showHint("")
		Remotes.EnterArena:FireServer()
	elseif zoneId == "BeyLab" then
		Remotes.OpenBeySelect:FireServer()
	end
end)

task.spawn(function()
	while true do
		task.wait(0.2)
		if not inHub then
			currentZone = nil
			continue
		end

		local zone = findNearestZone()
		if zone ~= currentZone then
			currentZone = zone
			if zone then
				showHint(zone:GetAttribute("Hint") or "")
			else
				showHint("")
			end
		end
	end
end)
