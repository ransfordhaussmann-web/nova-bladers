local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubDisplay = require(NovaBladers.HubDisplay)
local Remotes = NovaBladers:WaitForChild("Remotes")

local function waitForHub()
	return workspace:WaitForChild(HubConfig.ROOT_NAME, 30)
end

local function createHintGui()
	local gui = Instance.new("ScreenGui")
	gui.Name = "HubHint"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Hint"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.fromOffset(420, 52)
	frame.BackgroundColor3 = Color3.fromRGB(12, 16, 28)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(80, 160, 255)
	stroke.Thickness = 1.5
	stroke.Parent = frame

	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextColor3 = Color3.fromRGB(220, 230, 255)
	label.TextSize = 16
	label.Text = "Erkunde den Hub — Arena-Tor (Norden) · Stats (Westen) · Rangliste (Osten)"
	label.Parent = frame

	return gui
end

local function bindArenaPrompt(hub)
	local gate = hub:FindFirstChild("Zones")
		and hub.Zones:FindFirstChild("ArenaGate")
	if not gate then return end

	local portal = gate:FindFirstChild("Portal")
	local prompt = portal and portal:FindFirstChild("ArenaPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function()
		local gui = player.PlayerGui:FindFirstChild("Lobby")
		if gui then gui.Enabled = false end
		local hint = player.PlayerGui:FindFirstChild("HubHint")
		if hint then hint.Enabled = false end
		Remotes.EnterArena:FireServer()
	end)
end

local hub = waitForHub()
createHintGui()
bindArenaPrompt(hub)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	HubDisplay.updateStats(payload)
	if payload.leaderboard then
		HubDisplay.updateLeaderboard(payload.leaderboard)
	end

	local hint = player.PlayerGui:FindFirstChild("HubHint")
	if hint then hint.Enabled = true end
end)
