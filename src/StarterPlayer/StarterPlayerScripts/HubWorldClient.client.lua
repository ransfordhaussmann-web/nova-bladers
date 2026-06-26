local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local function isHubActive()
	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	return hub and hub:FindFirstChild("HubMode") and hub.HubMode.Value
end

local function applyHubLayout()
	if not isHubActive() then
		return
	end

	gui.Enabled = true
	panel.Visible = false

	local hint = panel:FindFirstChild("HubHint")
	if not hint then
		hint = Instance.new("TextLabel")
		hint.Name = "HubHint"
		hint.AnchorPoint = Vector2.new(0.5, 1)
		hint.Position = UDim2.new(0.5, 0, 1, -24)
		hint.Size = UDim2.fromOffset(520, 48)
		hint.BackgroundTransparency = 0.35
		hint.BackgroundColor3 = Color3.fromRGB(15, 18, 30)
		hint.TextColor3 = Color3.fromRGB(220, 230, 255)
		hint.Font = Enum.Font.Gotham
		hint.TextSize = 16
		hint.Text = "Laufe zum Arena-Portal (E) oder Bey Lab (E) — Stats & Rangliste an den Säulen"
		hint.Parent = panel

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = hint
	end
	hint.Visible = true
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideBattleUi()

	if payload.hubMode or isHubActive() then
		applyHubLayout()
		if panel:FindFirstChild("ModeLabel") then
			panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
		end
		return
	end
end)

Workspace.ChildAdded:Connect(function(child)
	if child.Name == HubConfig.HUB_FOLDER_NAME then
		task.defer(applyHubLayout)
	end
end)

if isHubActive() then
	applyHubLayout()
end
