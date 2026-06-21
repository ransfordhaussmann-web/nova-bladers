local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local inHub = true

local function setLobbyVisible(visible)
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if gui then
		gui.Enabled = visible
	end
end

local function hideBattleUi()
	for _, name in { "BattleHUD", "BeySelect", "MobileControls" } do
		local gui = player.PlayerGui:FindFirstChild(name)
		if gui then
			gui.Enabled = false
		end
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	hideBattleUi()
	if inHub then
		setLobbyVisible(false)
	else
		setLobbyVisible(true)
	end
end)

local function connectZonePrompts()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end

	for _, zoneFolder in zones:GetChildren() do
		local actionValue = zoneFolder:FindFirstChild("ZoneAction")
		local gate = zoneFolder:FindFirstChild("Gate")
		local prompt = gate and gate:FindFirstChild("ZonePrompt")
		if prompt and actionValue then
			prompt.Triggered:Connect(function()
				if actionValue.Value == "EnterArena" then
					Remotes.EnterArena:FireServer()
				elseif actionValue.Value == "OpenBeySelect" then
					Remotes.OpenBeySelect:FireServer()
				end
			end)
		end
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(message)
	local gui = player.PlayerGui:FindFirstChild("HubHint")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "HubHint"
		gui.ResetOnSpawn = false
		gui.Parent = player.PlayerGui

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.AnchorPoint = Vector2.new(0.5, 0)
		label.Position = UDim2.new(0.5, 0, 0, 12)
		label.Size = UDim2.fromOffset(420, 40)
		label.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
		label.BackgroundTransparency = 0.2
		label.TextColor3 = Color3.fromRGB(240, 240, 250)
		label.Font = Enum.Font.Gotham
		label.TextSize = 18
		label.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
	end

	local label = gui.Label
	label.Text = message
	gui.Enabled = true
	task.delay(3, function()
		if gui.Parent and label.Text == message then
			gui.Enabled = false
		end
	end)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

task.spawn(connectZonePrompts)
