local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local cachedPayload = nil
local promptConnections = {}

local function hideBattleUi()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function showHubHint()
	local gui = playerGui:FindFirstChild("HubHint")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "HubHint"
		gui.ResetOnSpawn = false
		gui.Parent = playerGui

		local label = Instance.new("TextLabel")
		label.Name = "Hint"
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 12)
		label.Size = UDim2.fromOffset(420, 36)
		label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		label.BackgroundTransparency = 0.25
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamMedium
		label.TextColor3 = Color3.fromRGB(230, 235, 245)
		label.TextSize = 16
		label.Text = "Laufe zu einer Zone: Arena · Bey Auswahl · Rangliste"
		label.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
	end
	gui.Enabled = true
end

local function hideHubHint()
	local gui = playerGui:FindFirstChild("HubHint")
	if gui then gui.Enabled = false end
end

local function showLeaderboardPopup(payload)
	local gui = playerGui:FindFirstChild("HubLeaderboard")
	if gui then gui:Destroy() end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubLeaderboard"
	gui.ResetOnSpawn = false
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(320, 280)
	frame.BackgroundColor3 = Color3.fromRGB(24, 26, 36)
	frame.BorderSizePixel = 0
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, -20, 0, 36)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextColor3 = Color3.fromRGB(255, 255, 255)
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Text = "Rangliste & Stats"
	title.Parent = frame

	local body = Instance.new("TextLabel")
	body.Name = "Body"
	body.Size = UDim2.new(1, -20, 1, -52)
	body.Position = UDim2.fromOffset(10, 44)
	body.BackgroundTransparency = 1
	body.Font = Enum.Font.Gotham
	body.TextSize = 16
	body.TextColor3 = Color3.fromRGB(210, 215, 225)
	body.TextXAlignment = Enum.TextXAlignment.Left
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.TextWrapped = true
	body.Parent = frame

	local lines = {
		string.format("Wins: %d  |  Losses: %d  |  Rank: %d", payload.wins, payload.losses, payload.rank),
		"",
		"🏆 Top Spieler:",
	}
	for _, entry in payload.leaderboard or {} do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if not payload.leaderboard or #payload.leaderboard == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	body.Text = table.concat(lines, "\n")

	task.delay(5, function()
		if gui and gui.Parent then
			gui:Destroy()
		end
	end)
end

local function openBeySelect()
	hideBattleUi()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	else
		Remotes.OpenBeySelect:FireServer()
	end
end

local function onPromptTriggered(action)
	if action == "EnterArena" then
		hideHubHint()
		local lobby = playerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
		Remotes.EnterArena:FireServer()
	elseif action == "OpenBeySelect" then
		openBeySelect()
	elseif action == "ShowLeaderboard" then
		if cachedPayload then
			showLeaderboardPopup(cachedPayload)
		end
	end
end

local function bindHubPrompts(folder)
	for _, conn in promptConnections do
		conn:Disconnect()
	end
	table.clear(promptConnections)

	for _, desc in folder:GetDescendants() do
		if desc:IsA("ProximityPrompt") and desc:GetAttribute("HubAction") then
			local action = desc:GetAttribute("HubAction")
			table.insert(promptConnections, desc.Triggered:Connect(function()
				onPromptTriggered(action)
			end))
		end
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	cachedPayload = payload
	if payload.inHub then
		hideBattleUi()
		showHubHint()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	showHubHint()
end)

local hubFolder = Workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
if hubFolder then
	bindHubPrompts(hubFolder)
	hubFolder.DescendantAdded:Connect(function(desc)
		if desc:IsA("ProximityPrompt") then
			task.defer(function()
				bindHubPrompts(hubFolder)
			end)
		end
	end)
end
