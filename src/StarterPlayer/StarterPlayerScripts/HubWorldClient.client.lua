local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(360, 48)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
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
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.fromRGB(230, 235, 255)
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local inHub = false
local activeZone = nil

local function hideHint()
	activeZone = nil
	hintGui.Enabled = false
end

local function showHint(zoneName, hint, hasAction)
	activeZone = zoneName
	hintLabel.Text = hasAction and string.format("[E] %s — %s", zoneName, hint) or string.format("%s — %s", zoneName, hint)
	hintGui.Enabled = true
end

local function trackZones()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones")
	local tracked = {}

	for _, zonePart in zones:GetChildren() do
		if not zonePart:IsA("BasePart") then continue end

		local zoneId = zonePart:GetAttribute("ZoneId")
		local zoneName = zonePart:GetAttribute("ZoneName") or zoneId
		local zoneHint = zonePart:GetAttribute("ZoneHint") or ""
		local zoneAction = zonePart:GetAttribute("ZoneAction")

		zonePart.Touched:Connect(function(hit)
			if not inHub then return end
			local character = hit:FindFirstAncestorOfClass("Model")
			if character ~= player.Character then return end
			tracked[zoneId] = true
			showHint(zoneName, zoneHint, zoneAction ~= nil and zoneAction ~= "")
		end)

		zonePart.TouchEnded:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			if character ~= player.Character then return end
			tracked[zoneId] = nil
			if activeZone == zoneName then
				hideHint()
			end
		end)
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	if not inHub then
		hideHint()
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(zoneName, hint, hasAction)
	if inHub then
		showHint(zoneName, hint, hasAction)
	end
end)

local UserInputService = game:GetService("UserInputService")
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub or not activeZone then return end
	if input.KeyCode == Enum.KeyCode.E then
		local hub = workspace:FindFirstChild("NovaHub")
		if not hub then return end
		local zones = hub:FindFirstChild("Zones")
		if not zones then return end

		for _, zonePart in zones:GetChildren() do
			if zonePart:GetAttribute("ZoneName") ~= activeZone then continue end
			local action = zonePart:GetAttribute("ZoneAction")
			if action == "EnterArena" then
				Remotes.EnterArena:FireServer()
			elseif action == "OpenBeySelect" then
				Remotes.OpenBeySelect:FireServer()
			end
			break
		end
	end
end)

task.spawn(trackZones)
