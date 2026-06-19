local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubHints"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -24)
hintLabel.Size = UDim2.new(0, 420, 0, 48)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintLabel.BackgroundTransparency = 0.25
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 18
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.Text = ""
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local hintToken = 0

local function showHint(text, duration)
	hintToken += 1
	local token = hintToken
	hintLabel.Text = text
	hintGui.Enabled = true
	task.delay(duration or 4, function()
		if token == hintToken then
			hintGui.Enabled = false
		end
	end)
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
	showHint("Wähle deinen Bey im Labor.", 5)
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(text)
	showHint(text, 4)
end)

local hub = workspace:WaitForChild("NovaHub", 30)
if hub then
	local zones = hub:WaitForChild("Zones")
	for _, zoneFolder in zones:GetChildren() do
		local platform = zoneFolder:FindFirstChild("Platform")
		if platform then
			platform.Touched:Connect(function(hit)
				local character = hit.Parent
				if character and character == player.Character then
					local prompt = platform:FindFirstChild("ZonePrompt")
					if prompt then
						showHint(prompt.ObjectText .. " — " .. prompt.ActionText, 3)
					end
				end
			end)
		end
	end

	showHint("Willkommen im Nova Hub! Erkunde die Zonen.", 6)
end
