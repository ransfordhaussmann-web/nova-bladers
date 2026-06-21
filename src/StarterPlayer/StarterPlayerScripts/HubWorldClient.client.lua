local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = playerGui

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 0.92, 0)
hintFrame.Size = UDim2.new(0.4, 0, 0.08, 0)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
hintFrame.BackgroundTransparency = 0.2
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
hintLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
hintLabel.TextScaled = true
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local hideToken = 0

local function showHint(payload)
	if not payload or not payload.hint then return end

	hideToken += 1
	local token = hideToken

	hintLabel.Text = string.format("%s — %s", payload.name or "Zone", payload.hint)
	hintGui.Enabled = true

	task.delay(3, function()
		if hideToken == token then
			hintGui.Enabled = false
		end
	end)
end

remotes.HubZoneHint.OnClientEvent:Connect(showHint)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local beySelect = playerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)
