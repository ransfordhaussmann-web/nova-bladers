--[[
	Client-Logik für die begehbare 3D-Hub-Welt.
	Blendet Kampf-UI aus, zeigt Hub-Hinweise und leitet Zonen-Aktionen weiter.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local HubState = Remotes:WaitForChild("HubState")
local OpenBeySelect = Remotes:WaitForChild("OpenBeySelect")
local EnterArena = Remotes:WaitForChild("EnterArena")

local inHub = true

local function setGuiEnabled(name: string, enabled: boolean)
	local gui = playerGui:FindFirstChild(name)
	if gui and gui:IsA("ScreenGui") then
		gui.Enabled = enabled
	end
end

local function applyHubUiState()
	if inHub then
		setGuiEnabled("BattleHUD", false)
		setGuiEnabled("MobileControls", false)
		setGuiEnabled("BeySelect", false)
	else
		setGuiEnabled("MobileControls", true)
	end
end

local function getOrCreateHintGui(): ScreenGui
	local existing = playerGui:FindFirstChild("HubHint")
	if existing then
		return existing
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "HubHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = playerGui

	local label = Instance.new("TextLabel")
	label.Name = "Hint"
	label.AnchorPoint = Vector2.new(0.5, 1)
	label.Position = UDim2.new(0.5, 0, 1, -24)
	label.Size = UDim2.fromOffset(520, 40)
	label.BackgroundColor3 = Color3.fromRGB(18, 22, 36)
	label.BackgroundTransparency = 0.35
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamMedium
	label.TextSize = 16
	label.TextColor3 = Color3.fromRGB(210, 220, 245)
	label.Text = "Nova Hub — Laufe zu einer Zone und drücke E"
	label.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = label

	return gui
end

local function updateHubHint()
	local hintGui = getOrCreateHintGui()
	hintGui.Enabled = inHub
end

HubState.OnClientEvent:Connect(function(payload)
	inHub = payload.inHub == true
	applyHubUiState()
	updateHubHint()
end)

OpenBeySelect.OnClientEvent:Connect(function()
	setGuiEnabled("BeySelect", true)
	setGuiEnabled("Lobby", false)
end)

EnterArena.OnClientEvent:Connect(function(payload)
	inHub = false
	applyHubUiState()
	updateHubHint()
	setGuiEnabled("Lobby", false)

	if payload and payload.mode == "training" then
		setGuiEnabled("BattleHUD", true)
	end

	EnterArena:FireServer()
end)

applyHubUiState()
updateHubHint()
