local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then
	return
end

local activeZoneId = nil
local padTweens = {}

local function getPads()
	local pads = {}
	for _, zone in HubConfig.ZONES do
		local pad = hub:FindFirstChild(zone.id .. "Pad")
		if pad then
			pads[zone.id] = pad
		end
	end
	return pads
end

local function setPadGlow(zoneId, enabled)
	local pad = getPads()[zoneId]
	if not pad then return end

	if padTweens[zoneId] then
		padTweens[zoneId]:Cancel()
		padTweens[zoneId] = nil
	end

	local targetTransparency = enabled and 0.1 or 0.35
	local tween = TweenService:Create(pad, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Transparency = targetTransparency,
	})
	padTweens[zoneId] = tween
	tween:Play()

	local light = pad:FindFirstChildOfClass("PointLight")
	if light then
		light.Brightness = enabled and 2.4 or 1.2
	end
end

local function ensureHintGui()
	local gui = player.PlayerGui:FindFirstChild("HubHint")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubHint"
	gui.ResetOnSpawn = false
	gui.Parent = player.PlayerGui

	local label = Instance.new("TextLabel")
	label.Name = "ZoneLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0.92, 0)
	label.Size = UDim2.fromOffset(360, 44)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 18
	label.Text = ""
	label.Visible = false
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return gui
end

local hintGui = ensureHintGui()
local hintLabel = hintGui.ZoneLabel

Remotes.HubZoneChanged.OnClientEvent:Connect(function(payload)
	local zoneId = payload.zoneId
	if zoneId == activeZoneId then return end

	if activeZoneId then
		setPadGlow(activeZoneId, false)
	end

	activeZoneId = zoneId

	if zoneId then
		setPadGlow(zoneId, true)
		hintLabel.Text = payload.label or zoneId
		hintLabel.Visible = true
	else
		hintLabel.Visible = false
	end
end)

for zoneId, pad in getPads() do
	task.spawn(function()
		while pad.Parent do
			if zoneId ~= activeZoneId then
				local light = pad:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = 1.0 + math.sin(os.clock() * 2) * 0.2
				end
			end
			task.wait(0.1)
		end
	end)
end
