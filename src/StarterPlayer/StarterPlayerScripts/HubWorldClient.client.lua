local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui
local hintLabel
local hintHideToken = 0

local function ensureHintGui()
	if hintGui then return end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "HubZoneHint"
	hintGui.ResetOnSpawn = false
	hintGui.DisplayOrder = 20
	hintGui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 16)
	frame.Size = UDim2.new(0, 360, 0, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "Hint"
	hintLabel.Size = UDim2.new(1, -20, 1, -12)
	hintLabel.Position = UDim2.new(0, 10, 0, 6)
	hintLabel.BackgroundTransparency = 1
	hintLabel.TextColor3 = Color3.new(1, 1, 1)
	hintLabel.TextScaled = true
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.Text = ""
	hintLabel.Parent = frame
end

local function showZoneHint(payload)
	ensureHintGui()
	local frame = hintGui.Panel
	hintLabel.Text = string.format("%s\n%s", payload.name, payload.hint)
	frame.Visible = true

	hintHideToken += 1
	local token = hintHideToken
	task.delay(3.5, function()
		if hintHideToken == token then
			frame.Visible = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end

	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local hub = workspace:FindFirstChild("NovaHub")
	if not hub then return end

	local zones = hub:FindFirstChild("Zones")
	if not zones then return end

	for _, zoneFolder in zones:GetChildren() do
		local trigger = zoneFolder:FindFirstChild("Trigger")
		if trigger then
			local dist = (root.Position - trigger.Position).Magnitude
			if dist < math.max(trigger.Size.X, trigger.Size.Z) * 0.6 then
				Remotes.EnterArena:FireServer()
				return
			end
		end
	end
end)
