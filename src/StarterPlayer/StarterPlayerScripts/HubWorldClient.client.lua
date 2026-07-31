local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = false
local activeZone = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "Hint"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
hintFrame.Size = UDim2.fromOffset(360, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Text"
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.fromRGB(235, 238, 245)
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local function getRootPart()
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findNearestZone(position)
	local nearest = nil
	local nearestDist = HubConfig.INTERACT_DISTANCE + 1
	for _, zone in HubConfig.ZONES do
		local dist = (Vector3.new(position.X, 0, position.Z) - Vector3.new(zone.position.X, 0, zone.position.Z)).Magnitude
		if dist <= zone.radius and dist < nearestDist then
			nearest = zone
			nearestDist = dist
		end
	end
	return nearest
end

local function showHint(text)
	hintLabel.Text = text or ""
	hintGui.Enabled = text ~= nil and text ~= ""
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		activeZone = nil
		showHint(nil)
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(data)
	if typeof(data) ~= "table" then
		return
	end
	local text = data.title or ""
	if data.body then
		text = text .. "\n" .. data.body
	end
	showHint(text)
	task.delay(4, function()
		if activeZone then
			showHint(activeZone.hint)
		else
			showHint(nil)
		end
	end)
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not activeZone then
		return
	end
	if input.KeyCode == HubConfig.INTERACT_KEY then
		Remotes.HubInteract:FireServer(activeZone.id)
	end
end)

task.spawn(function()
	while true do
		task.wait(0.15)
		if not inHub then
			activeZone = nil
			showHint(nil)
			continue
		end

		local root = getRootPart()
		if not root then
			activeZone = nil
			showHint(nil)
			continue
		end

		local zone = findNearestZone(root.Position)
		if zone ~= activeZone then
			activeZone = zone
			if zone then
				showHint(zone.hint)
			else
				showHint(nil)
			end
		end
	end
end)
