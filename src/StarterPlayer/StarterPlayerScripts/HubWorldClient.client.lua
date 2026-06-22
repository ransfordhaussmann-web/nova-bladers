local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function setBattleUiEnabled(enabled)
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = enabled
	end

	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = enabled
	end
end

local function ensureHintGui()
	local existing = player.PlayerGui:FindFirstChild("HubHint")
	if existing then
		return existing
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubHint"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player.PlayerGui

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -24)
	label.Size = UDim2.new(0, 360, 0, 48)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(240, 240, 255)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 18
	label.Text = ""
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	return gui
end

local hintGui = ensureHintGui()
local hintLabel = hintGui.HintLabel

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local action = prompt:GetAttribute("Action")
	if action then
		Remotes.HubZoneAction:FireServer(action)
	end
end)

ProximityPromptService.PromptShown:Connect(function(prompt)
	local zoneId = prompt:GetAttribute("ZoneId")
	if zoneId then
		hintGui.Enabled = true
		hintLabel.Text = string.format("%s — Drücke E", prompt.ActionText)
	end
end)

ProximityPromptService.PromptHidden:Connect(function(prompt)
	if prompt:GetAttribute("ZoneId") then
		hintGui.Enabled = false
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	hintGui.Enabled = true
	hintLabel.Text = string.format("%s — %s", payload.name or "Zone", payload.hint or "")
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	setBattleUiEnabled(false)

	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end

	hintGui.Enabled = false
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
