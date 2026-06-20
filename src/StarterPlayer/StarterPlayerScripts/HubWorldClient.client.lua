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
hintFrame.Position = UDim2.new(0.5, 0, 1, -80)
hintFrame.Size = UDim2.fromOffset(360, 56)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
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
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextScaled = true
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.Text = ""
hintLabel.Parent = hintFrame

local hideToken = 0

local function showHint(text)
	hideToken += 1
	local token = hideToken
	hintLabel.Text = text
	hintGui.Enabled = true
	task.delay(3, function()
		if hideToken == token then
			hintGui.Enabled = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	local text = payload.hint or payload.zone or ""
	if payload.action == "EnterArena" then
		text ..= " — betreten..."
	elseif payload.action == "OpenBeySelect" then
		text ..= " — Bey-Auswahl öffnet sich."
	elseif payload.action == "ShowStats" then
		text ..= " — Stats werden angezeigt."
	end
	showHint(text)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
