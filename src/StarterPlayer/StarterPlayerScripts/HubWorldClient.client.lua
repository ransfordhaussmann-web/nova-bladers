local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local hintGui

local function ensureHintGui()
	if hintGui then
		return hintGui
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubOverlay"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "HintBar"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -16)
	frame.Size = UDim2.new(0.6, 0, 0, 44)
	frame.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextScaled = true
	label.Text = "Nova Hub — laufe zu Arena, Bey-Shop oder Ruhmeshalle"
	label.Parent = frame

	hintGui = screen
	return screen
end

local function setHubOverlayVisible(visible)
	local gui = ensureHintGui()
	gui.Enabled = visible
end

Remotes.HubState.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub ~= false
	setHubOverlayVisible(inHub)

	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.RefreshHubStats.OnClientEvent:Connect(function()
	-- StatsBoard wird serverseitig aktualisiert; Client braucht keine Aktion.
end)

ensureHintGui()
setHubOverlayVisible(true)
