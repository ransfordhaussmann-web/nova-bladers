local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local MatchmakingConfig = require(ReplicatedStorage.NovaBladers.MatchmakingConfig)

local gui
local panel
local statusLabel
local detailLabel
local leaveButton

local function ensureGui()
	if gui then
		return
	end

	gui = Instance.new("ScreenGui")
	gui.Name = "MatchmakingQueue"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.Parent = player:WaitForChild("PlayerGui")

	panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(280, 120)
	panel.Position = UDim2.new(0.5, -140, 0, 16)
	panel.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	panel.BackgroundTransparency = 0.1
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = panel

	statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "StatusLabel"
	statusLabel.Size = UDim2.new(1, -16, 0, 28)
	statusLabel.Position = UDim2.fromOffset(8, 8)
	statusLabel.BackgroundTransparency = 1
	statusLabel.Font = Enum.Font.GothamBold
	statusLabel.TextSize = 16
	statusLabel.TextColor3 = Color3.fromRGB(120, 180, 255)
	statusLabel.TextXAlignment = Enum.TextXAlignment.Left
	statusLabel.Text = "Warteschlange"
	statusLabel.Parent = panel

	detailLabel = Instance.new("TextLabel")
	detailLabel.Name = "DetailLabel"
	detailLabel.Size = UDim2.new(1, -16, 0, 48)
	detailLabel.Position = UDim2.fromOffset(8, 36)
	detailLabel.BackgroundTransparency = 1
	detailLabel.Font = Enum.Font.GothamMedium
	detailLabel.TextSize = 13
	detailLabel.TextColor3 = Color3.new(1, 1, 1)
	detailLabel.TextXAlignment = Enum.TextXAlignment.Left
	detailLabel.TextYAlignment = Enum.TextYAlignment.Top
	detailLabel.TextWrapped = true
	detailLabel.Text = ""
	detailLabel.Parent = panel

	leaveButton = Instance.new("TextButton")
	leaveButton.Name = "LeaveButton"
	leaveButton.Size = UDim2.fromOffset(120, 28)
	leaveButton.Position = UDim2.fromOffset(8, 84)
	leaveButton.BackgroundColor3 = Color3.fromRGB(180, 70, 70)
	leaveButton.Font = Enum.Font.GothamBold
	leaveButton.TextSize = 13
	leaveButton.TextColor3 = Color3.new(1, 1, 1)
	leaveButton.Text = "Verlassen"
	leaveButton.Parent = panel

	local btnCorner = Instance.new("UICorner")
	btnCorner.CornerRadius = UDim.new(0, 6)
	btnCorner.Parent = leaveButton

	leaveButton.MouseButton1Click:Connect(function()
		Remotes.QueueLeave:FireServer()
		gui.Enabled = false
	end)
end

local function formatDetail(payload)
	local mode = MatchmakingConfig.MODES[payload.modeId]
	local label = payload.modeLabel or (mode and mode.label) or payload.modeId
	local countText = string.format("%d / %d Spieler", payload.queueCount or 0, payload.minPlayers or 1)

	if payload.pendingArena then
		return string.format("%s\n%s — Arena belegt, du bist vorgemerkt.", label, countText)
	end

	if payload.modeId == "ffa" and payload.fillEndsAt then
		local remaining = math.max(0, math.ceil(payload.fillEndsAt - os.clock()))
		return string.format("%s\n%s — Match startet in %ds", label, countText, remaining)
	end

	return string.format("%s\n%s — Warte auf Gegner…", label, countText)
end

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	ensureGui()

	if payload.inQueue then
		statusLabel.Text = payload.pendingArena and "Vorgemerkt" or "In Warteschlange"
		detailLabel.Text = formatDetail(payload)
		gui.Enabled = true
	else
		gui.Enabled = false
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "arena" and gui then
		gui.Enabled = false
	end
end)
