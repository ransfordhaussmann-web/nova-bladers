local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function applyHubLayout()
	-- Compact overlay: player can walk the 3D hub while seeing stats
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, 16)
	if panel:FindFirstChild("UISizeConstraint") == nil then
		local constraint = Instance.new("UISizeConstraint")
		constraint.MaxSize = Vector2.new(280, 400)
		constraint.Parent = panel
	end
	if panel:FindFirstChild("StartButton") then
		panel.StartButton.Text = "Zur Arena"
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
		local lines = {"🏆 Top Spieler:"}
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
	end

	gui.Enabled = true
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)

-- Re-show compact stats when returning to hub from a match
player:GetAttributeChangedSignal("InHub"):Connect(function()
	if player:GetAttribute("InHub") then
		hideOthers()
		gui.Enabled = true
	end
end)
