local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -24)
hintLabel.Size = UDim2.fromOffset(400, 40)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.Font = Enum.Font.Gotham
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.Text = ""
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local function showHint(text)
	hintLabel.Text = text
	hintGui.Enabled = text ~= ""
end

local function hideHint()
	showHint("")
end

local function connectZonePrompts()
	local hub = workspace:WaitForChild(HubConfig.HUB_NAME, 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end

	for _, pad in zones:GetChildren() do
		local prompt = pad:FindFirstChild("HubPrompt")
		if not prompt then continue end

		local zoneId = pad:GetAttribute("ZoneId")
		local zone = HubConfig.ZONES[zoneId]
		if zone then
			prompt.PromptShown:Connect(function()
				showHint(zone.hint)
			end)
			prompt.PromptHidden:Connect(function()
				hideHint()
			end)
		end

		local action = pad:GetAttribute("HubAction")
		prompt.Triggered:Connect(function()
			if action == "EnterArena" then
				Remotes.EnterArena:FireServer()
			elseif action == "OpenBeySelect" then
				Remotes.OpenBeySelect:FireServer()
			end
		end)
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(text)
	showHint(text or "")
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

task.spawn(connectZonePrompts)
