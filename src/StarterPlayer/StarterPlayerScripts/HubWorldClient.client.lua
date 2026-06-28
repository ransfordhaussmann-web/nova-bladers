local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hub = workspace:WaitForChild("NovaHub", 30)
local arenaPad = hub and hub:WaitForChild("ArenaPad", 10)

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubHints"
hintGui.ResetOnSpawn = false
hintGui.DisplayOrder = 5
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "ZoneHint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 1, -24)
hintLabel.Size = UDim2.new(0.6, 0, 0, 36)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
hintLabel.BackgroundTransparency = 0.35
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.TextSize = 16
hintLabel.Text = ""
hintLabel.Visible = false
hintLabel.Parent = hintGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 8)
corner.Parent = hintLabel

local hintHideToken = 0

local function showHint(text)
	if not text or text == "" then
		hintLabel.Visible = false
		return
	end
	hintHideToken += 1
	local token = hintHideToken
	hintLabel.Text = text
	hintLabel.Visible = true
	task.delay(4, function()
		if hintHideToken == token then
			hintLabel.Visible = false
		end
	end)
end

Remotes.HubZoneChanged.OnClientEvent:Connect(function(payload)
	showHint(payload.hint)
end)

if arenaPad then
	local baseColor = arenaPad.Color
	local glowTime = 0
	RunService.RenderStepped:Connect(function(dt)
		if not arenaPad.Parent then return end
		glowTime += dt
		local pulse = 0.5 + 0.5 * math.sin(glowTime * 2.5)
		arenaPad.Transparency = 0.15 + pulse * 0.2
		arenaPad.Color = baseColor:Lerp(Color3.new(1, 1, 1), pulse * 0.15)
		local light = arenaPad:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 1.5 + pulse * 1.5
		end
	end)
end

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	showHint("Zurück im Nova Hub")
end)
