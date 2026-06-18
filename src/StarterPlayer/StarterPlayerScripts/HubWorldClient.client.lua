local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hubGui

local function ensureHubHud()
	if hubGui then
		return hubGui
	end

	hubGui = Instance.new("ScreenGui")
	hubGui.Name = "HubHUD"
	hubGui.ResetOnSpawn = false
	hubGui.Enabled = false
	hubGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "StatsBar"
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Position = UDim2.new(0.5, 0, 0, 12)
	frame.Size = UDim2.fromOffset(340, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Parent = hubGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = frame

	local statsLabel = Instance.new("TextLabel")
	statsLabel.Name = "StatsLabel"
	statsLabel.BackgroundTransparency = 1
	statsLabel.Position = UDim2.fromOffset(12, 8)
	statsLabel.Size = UDim2.new(1, -24, 0, 28)
	statsLabel.Font = Enum.Font.GothamBold
	statsLabel.TextColor3 = Color3.new(1, 1, 1)
	statsLabel.TextSize = 16
	statsLabel.TextXAlignment = Enum.TextXAlignment.Left
	statsLabel.Text = "Nova Bladers Hub"
	statsLabel.Parent = frame

	local modeLabel = Instance.new("TextLabel")
	modeLabel.Name = "ModeLabel"
	modeLabel.BackgroundTransparency = 1
	modeLabel.Position = UDim2.fromOffset(12, 36)
	modeLabel.Size = UDim2.new(1, -24, 0, 24)
	modeLabel.Font = Enum.Font.Gotham
	modeLabel.TextColor3 = Color3.fromRGB(180, 190, 210)
	modeLabel.TextSize = 14
	modeLabel.TextXAlignment = Enum.TextXAlignment.Left
	modeLabel.Text = ""
	modeLabel.Parent = frame

	local hintLabel = Instance.new("TextLabel")
	hintLabel.Name = "HintLabel"
	hintLabel.AnchorPoint = Vector2.new(0.5, 1)
	hintLabel.Position = UDim2.new(0.5, 0, 1, -24)
	hintLabel.Size = UDim2.fromOffset(420, 32)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.Gotham
	hintLabel.TextColor3 = Color3.fromRGB(200, 210, 230)
	hintLabel.TextSize = 14
	hintLabel.Text = "Laufe zu Arena-Tor, Bey-Labor oder Ruhmeshalle"
	hintLabel.Parent = hubGui

	return hubGui
end

local function showHubHud(payload)
	local gui = ensureHubHud()
	gui.StatsBar.StatsLabel.Text = string.format(
		"Wins: %d  |  Losses: %d  |  Rank: %d",
		payload.wins or 0,
		payload.losses or 0,
		payload.rank or 0
	)
	gui.StatsBar.ModeLabel.Text = payload.modeLabel or ""
	gui.Enabled = true
end

local function hideHubHud()
	if hubGui then
		hubGui.Enabled = false
	end
end

local function hideBattleUi()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function bindPrompt(prompt)
	if not prompt:IsA("ProximityPrompt") then return end
	local remoteName = prompt:GetAttribute("RemoteName")
	if typeof(remoteName) ~= "string" then return end

	local remote = remotes:FindFirstChild(remoteName)
	if not remote then return end

	prompt.Triggered:Connect(function()
		if remoteName == "EnterArena" then
			local lobby = playerGui:FindFirstChild("Lobby")
			if lobby then lobby.Enabled = false end
			hideBattleUi()
			hideHubHud()
		elseif remoteName == "OpenBeySelect" then
			local select = playerGui:FindFirstChild("BeySelect")
			if select then select.Enabled = true end
		end
		remote:FireServer()
	end)
end

local function bindHub(hub)
	local zones = hub:WaitForChild("Zones")
	for _, zone in zones:GetChildren() do
		local pad = zone:FindFirstChild("Pad")
		if pad then
			local prompt = pad:FindFirstChild("ZonePrompt")
			if prompt then
				bindPrompt(prompt)
			end
		end
	end
end

remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		hideBattleUi()
		showHubHud(payload)
	end
end)

remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end)

local existingHub = workspace:FindFirstChild("NovaHub")
if existingHub then
	bindHub(existingHub)
else
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "NovaHub" then
			bindHub(child)
		end
	end)
end

ensureHubHud()
