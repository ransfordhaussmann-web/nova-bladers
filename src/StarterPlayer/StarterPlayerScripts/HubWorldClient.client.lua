local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers:WaitForChild("HubConfig"))
local Remotes = NovaBladers:WaitForChild("Remotes")

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.fromOffset(420, 44)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.fromRGB(230, 235, 255)
hintLabel.TextSize = 18
hintLabel.Text = ""
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local currentZone = nil

local function setHint(text)
	if text and text ~= "" then
		hintLabel.Text = text
		hintGui.Enabled = true
	else
		hintGui.Enabled = false
	end
end

local function getNearestZone(rootPos)
	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return nil end
	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end

	local nearest = nil
	local nearestDist = math.huge

	for _, zone in zones:GetChildren() do
		local platform = zone:FindFirstChild("Platform")
		if platform then
			local dist = (Vector3.new(rootPos.X, 0, rootPos.Z) - Vector3.new(platform.Position.X, 0, platform.Position.Z)).Magnitude
			local reach = math.max(platform.Size.X, platform.Size.Z) * 0.55 + 3
			if dist <= reach and dist < nearestDist then
				nearest = zone
				nearestDist = dist
			end
		end
	end

	return nearest
end

Remotes.HubZoneAction.OnClientEvent:Connect(function(payload)
	if payload.zoneId == "HallOfFame" and payload.leaderboard then
		local lines = {"🏆 Top Spieler:"}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		setHint(table.concat(lines, "  |  "))
		task.delay(5, function()
			if currentZone and currentZone.Name == "HallOfFame" then
				local hint = currentZone:FindFirstChild("HintText")
				setHint(hint and hint.Value or nil)
			else
				setHint(nil)
			end
		end)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

RunService.Heartbeat:Connect(function()
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local zone = getNearestZone(root.Position)
	if zone ~= currentZone then
		currentZone = zone
		if zone then
			local hint = zone:FindFirstChild("HintText")
			setHint(hint and hint.Value or nil)
		else
			setHint(nil)
		end
	end
end)

-- Zone definitions for client reference
local _ = HubConfig.ZONES
