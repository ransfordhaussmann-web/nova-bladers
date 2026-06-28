local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local selectedMode = nil

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

Remotes.HubZoneHighlight.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then return end
	if payload.modeLabel then
		panel.ModeLabel.Text = payload.modeLabel
	end
	if payload.zoneId then
		for _, zone in HubConfig.ZONES do
			if zone.id == payload.zoneId then
				selectedMode = zone.mode
				break
			end
		end
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = {"🏆 Top Spieler:"}
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end

	if payload.inHub == false then
		gui.Enabled = false
	else
		gui.Enabled = true
		if payload.arenaMode then
			selectedMode = payload.arenaMode
		end
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer(selectedMode)
end)

-- Compact overlay while walking the 3D hub.
if panel:FindFirstChild("HintLabel") == nil then
	local hint = Instance.new("TextLabel")
	hint.Name = "HintLabel"
	hint.Size = UDim2.new(1, -20, 0, 36)
	hint.Position = UDim2.new(0, 10, 1, -46)
	hint.BackgroundTransparency = 0.4
	hint.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 14
	hint.TextColor3 = Color3.fromRGB(180, 200, 255)
	hint.Text = "Laufe zu einer Zone oder nutze Start"
	hint.Parent = panel

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 6)
	corner.Parent = hint
end
