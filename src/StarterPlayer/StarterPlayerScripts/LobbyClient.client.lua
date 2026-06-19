local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local HUB_PANEL_SIZE = UDim2.fromOffset(280, 220)
local HUB_PANEL_POS = UDim2.new(1, -296, 0, 16)

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function applyHubLayout()
	panel.AnchorPoint = Vector2.new(0, 0)
	panel.Position = HUB_PANEL_POS
	panel.Size = HUB_PANEL_SIZE
	if panel:FindFirstChild("UICorner") == nil then
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 10)
		corner.Parent = panel
	end
	if panel:FindFirstChild("UIStroke") == nil then
		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(90, 160, 255)
		stroke.Thickness = 1.5
		stroke.Transparency = 0.35
		stroke.Parent = panel
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()

	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"

	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = {"Top Spieler:"}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end

	if payload.inHub then
		applyHubLayout()
		if panel:FindFirstChild("HintLabel") then
			panel.HintLabel.Text = "Laufe zur Arena oder nutze Start"
		end
	end

	gui.Enabled = true
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)
