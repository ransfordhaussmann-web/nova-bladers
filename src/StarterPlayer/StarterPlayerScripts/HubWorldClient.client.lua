local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local activeZone = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -80)
hintFrame.Size = UDim2.fromOffset(360, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamBold
hintLabel.TextColor3 = Color3.fromRGB(240, 240, 250)
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local function getCharacterRoot()
	local character = player.Character
	if not character then
		return nil
	end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findNearestZone()
	local root = getCharacterRoot()
	if not root or not inHub then
		return nil
	end

	local hub = workspace:FindFirstChild(HubConfig.HUB_NAME)
	if not hub then
		return nil
	end

	local nearestZone = nil
	local nearestDistance = HubConfig.PROXIMITY_RANGE

	for _, zone in HubConfig.ZONES do
		local distance = (root.Position - zone.position).Magnitude
		if distance <= nearestDistance then
			nearestDistance = distance
			nearestZone = zone
		end
	end

	return nearestZone
end

local function showHint(zone)
	if not zone then
		hintGui.Enabled = false
		activeZone = nil
		return
	end
	activeZone = zone
	hintLabel.Text = zone.hint
	hintGui.Enabled = true
end

local function triggerZoneAction(zone)
	if not zone or not inHub then
		return
	end
	Remotes.HubZoneAction:FireServer(zone.id)
end

RunService.Heartbeat:Connect(function()
	if not inHub then
		if hintGui.Enabled then
			hintGui.Enabled = false
			activeZone = nil
		end
		return
	end
	showHint(findNearestZone())
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then
		return
	end
	if input.KeyCode == Enum.KeyCode.E and activeZone then
		triggerZoneAction(activeZone)
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		hintGui.Enabled = false
		activeZone = nil
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if not payload or not payload.lines then
		return
	end
	local lines = { payload.title or "Ruhmeshalle" }
	for _, entry in payload.lines do
		table.insert(lines, string.format("%d. %s (%d Pkt)", entry.rank, entry.name, entry.points))
	end
	if #payload.lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	hintLabel.Text = table.concat(lines, "\n")
	hintFrame.Size = UDim2.fromOffset(360, 120)
	hintGui.Enabled = true
	task.delay(4, function()
		hintFrame.Size = UDim2.fromOffset(360, 56)
		if inHub then
			showHint(findNearestZone())
		else
			hintGui.Enabled = false
		end
	end)
end)

local hub = workspace:WaitForChild(HubConfig.HUB_NAME, 30)
if hub then
	local zonesFolder = hub:WaitForChild("Zones", 10)
	if zonesFolder then
		for _, zonePart in zonesFolder:GetChildren() do
			local prompt = zonePart:FindFirstChild("ZonePrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Triggered:Connect(function()
					triggerZoneAction({
						id = zonePart.Name,
					})
				end)
			end
		end
	end
end
