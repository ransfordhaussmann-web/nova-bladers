local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")
local HubWorldConfig = require(NovaBladers.HubWorldConfig)

local selectedModeId = "Training"

local function findOrCreateHint()
	local playerGui = player:WaitForChild("PlayerGui")
	local existing = playerGui:FindFirstChild("HubHint")
	if existing then
		return existing
	end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "HubHint"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "ModeHint"
	label.AnchorPoint = Vector2.new(0.5, 0)
	label.Position = UDim2.new(0.5, 0, 0, 12)
	label.Size = UDim2.fromOffset(420, 36)
	label.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	label.BackgroundTransparency = 0.25
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(230, 240, 255)
	label.TextSize = 18
	label.Text = "Hub: Wähle einen Modus-Pad"
	label.Parent = screenGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	return screenGui
end

local hintGui = findOrCreateHint()
local hintLabel = hintGui:WaitForChild("ModeHint")

local function updateHint(modeLabel)
	hintLabel.Text = string.format("Hub · %s · Pad betreten oder Lobby-Start", modeLabel)
end

local function bindPadVisuals()
	local hub = workspace:WaitForChild(HubWorldConfig.HUB_FOLDER_NAME, 30)
	if not hub then
		return
	end

	local interactables = hub:WaitForChild("Interactables", 10)
	if not interactables then
		return
	end

	for _, padConfig in HubWorldConfig.MODE_PADS do
		local pad = interactables:WaitForChild("ModePad_" .. padConfig.id, 10)
		if not pad then
			continue
		end

		local prompt = pad:WaitForChild("EnterPrompt", 5)
		if not prompt then
			continue
		end

		prompt.PromptShown:Connect(function()
			Remotes.SelectHubMode:FireServer(padConfig.id)
		end)
	end
end

Remotes.HubModeChanged.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	selectedModeId = payload.modeId or selectedModeId
	updateHint(payload.modeLabel or "Modus: Training")
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub ~= false then
		hintGui.Enabled = true
		updateHint(payload.modeLabel or "Modus: Training")
	else
		hintGui.Enabled = false
	end
end)

updateHint("Modus: Training")
task.defer(bindPadVisuals)
