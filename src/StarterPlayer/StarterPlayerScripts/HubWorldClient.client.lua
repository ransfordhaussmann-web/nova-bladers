local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
hintFrame.Size = UDim2.new(0.5, 0, 0, 80)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 35)
hintFrame.BackgroundTransparency = 0.2
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 28)
titleLabel.Position = UDim2.new(0, 8, 0, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.TextColor3 = HubConfig.ACCENT_COLOR
titleLabel.TextScaled = true
titleLabel.Font = Enum.Font.GothamBold
titleLabel.Text = ""
titleLabel.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.Size = UDim2.new(1, -16, 0, 40)
hintLabel.Position = UDim2.new(0, 8, 0, 34)
hintLabel.BackgroundTransparency = 1
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextScaled = true
hintLabel.Font = Enum.Font.Gotham
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local hideToken = 0

local function showHint(data)
	if not data.visible then
		hintGui.Enabled = false
		return
	end

	hideToken += 1
	local token = hideToken

	titleLabel.Text = data.zoneName or ""
	hintLabel.Text = data.hint or ""
	hintGui.Enabled = true

	local duration = data.duration
	if duration and duration > 0 then
		task.delay(duration, function()
			if hideToken == token then
				hintGui.Enabled = false
			end
		end)
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

local function checkZoneProximity()
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end

	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if not hub then return end

	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	local nearestZone = nil
	local nearestDist = math.huge

	for zoneId, zone in HubConfig.ZONES do
		local zoneFolder = zones:FindFirstChild(zoneId)
		if zoneFolder then
			local trigger = zoneFolder:FindFirstChild("Trigger")
			if trigger then
				local dist = (hrp.Position - trigger.Position).Magnitude
				if dist < 14 and dist < nearestDist then
					nearestDist = dist
					nearestZone = zone
				end
			end
		end
	end

	if nearestZone then
		showHint({
			visible = true,
			zoneName = nearestZone.name,
			hint = nearestZone.hint,
		})
	else
		showHint({ visible = false })
	end
end

task.spawn(function()
	while true do
		task.wait(0.5)
		if hintGui.Enabled or workspace:FindFirstChild(HubConfig.HUB_FOLDER) then
			checkZoneProximity()
		end
	end
end)
