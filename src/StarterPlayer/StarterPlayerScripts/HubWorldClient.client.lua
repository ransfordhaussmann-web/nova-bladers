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
hintFrame.Name = "Panel"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(360, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
hintFrame.BackgroundTransparency = 0.15
hintFrame.BorderSizePixel = 0
hintFrame.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -16, 0, 24)
titleLabel.Position = UDim2.fromOffset(8, 6)
titleLabel.BackgroundTransparency = 1
titleLabel.Font = Enum.Font.GothamBold
titleLabel.TextColor3 = Color3.fromRGB(255, 210, 90)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.TextSize = 18
titleLabel.Text = ""
titleLabel.Parent = hintFrame

local messageLabel = Instance.new("TextLabel")
messageLabel.Name = "Message"
messageLabel.Size = UDim2.new(1, -16, 0, 20)
messageLabel.Position = UDim2.fromOffset(8, 30)
messageLabel.BackgroundTransparency = 1
messageLabel.Font = Enum.Font.Gotham
messageLabel.TextColor3 = Color3.new(1, 1, 1)
messageLabel.TextXAlignment = Enum.TextXAlignment.Left
messageLabel.TextSize = 16
messageLabel.Text = ""
messageLabel.Parent = hintFrame

local hintToken = 0

local function showHint(payload)
	hintToken += 1
	local token = hintToken
	titleLabel.Text = payload.title or "Hub"
	messageLabel.Text = payload.message or ""
	hintGui.Enabled = true
	task.delay(4, function()
		if token == hintToken then
			hintGui.Enabled = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
	showHint({
		title = "Bey-Labor",
		message = "Wähle deinen Bey für den nächsten Kampf.",
	})
end)

local hub = workspace:WaitForChild("NovaHub", 30)
if hub then
	local zones = hub:WaitForChild("Zones", 10)
	if zones then
		for _, marker in zones:GetChildren() do
			local prompt = marker:FindFirstChild("ZonePrompt")
			local zoneId = marker:GetAttribute("ZoneId")
			if prompt and zoneId then
				prompt.PromptShown:Connect(function()
					showHint({
						title = prompt.ObjectText,
						message = prompt.ActionText,
					})
				end)
			end
		end
	end
end
