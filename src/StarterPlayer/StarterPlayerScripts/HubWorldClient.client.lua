local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui
local lastHintTime = 0

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubHints"
	screen.ResetOnSpawn = false
	screen.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "HintLabel"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 0.92, 0)
	label.Size = UDim2.fromOffset(400, 48)
	label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	label.BackgroundTransparency = 0.25
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 18
	label.TextWrapped = true
	label.Visible = false
	label.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	hintGui = label
	return label
end

local function showHint(text)
	local now = tick()
	if now - lastHintTime < HubConfig.HINT_COOLDOWN then return end
	lastHintTime = now

	local label = ensureHintGui()
	label.Text = text
	label.Visible = true
	task.delay(3, function()
		if label.Text == text then
			label.Visible = false
		end
	end)
end

local function connectZone(zonePart)
	local actionValue = zonePart:FindFirstChild("Action")
	local prompt = zonePart:FindFirstChild("Interact")
	if not actionValue or not prompt then return end

	local zoneConfig
	for _, zone in HubConfig.ZONES do
		if zone.id == zonePart.Name then
			zoneConfig = zone
			break
		end
	end

	prompt.Triggered:Connect(function()
		local action = actionValue.Value
		if action == "enterArena" then
			Remotes.EnterArena:FireServer()
		elseif action == "openBeySelect" then
			Remotes.OpenBeySelect:FireServer()
		elseif action == "showStats" then
			local gui = player.PlayerGui:FindFirstChild("Lobby")
			if gui then
				local panel = gui:FindFirstChild("Panel")
				if panel then
					gui.Enabled = true
					task.delay(5, function()
						if gui.Enabled then
							gui.Enabled = false
						end
					end)
				end
			end
		end
	end)

	if zoneConfig then
		prompt.PromptShown:Connect(function()
			showHint(zoneConfig.hint)
		end)
	end
end

local function watchHub()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then return end
	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end
	for _, zonePart in zones:GetChildren() do
		connectZone(zonePart)
	end
	zones.ChildAdded:Connect(connectZone)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showHint)
Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

task.spawn(watchHub)
