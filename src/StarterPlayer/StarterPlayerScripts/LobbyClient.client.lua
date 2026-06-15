local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local hubMode = false
local lastPayload = nil

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function applyPayload(payload)
	lastPayload = payload
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
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyPayload(payload)
	hubMode = payload.hubEnabled == true

	if hubMode then
		-- 3D hub: walk the map; overlay stays hidden until terminal or manual open
		gui.Enabled = false
		if panel:FindFirstChild("HubHintLabel") then
			panel.HubHintLabel.Text = "Lauf zum Arena-Portal, Training-Pad oder Terminal"
		end
	else
		gui.Enabled = true
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(data)
	if not hubMode or not lastPayload then return end
	applyPayload(lastPayload)
	gui.Enabled = true
	if panel:FindFirstChild("HubHintLabel") then
		local zoneName = data.zoneId or "Terminal"
		panel.HubHintLabel.Text = "Terminal: " .. zoneName
	end
	task.delay(4, function()
		if hubMode and gui.Enabled then
			gui.Enabled = false
		end
	end)
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	gui.Enabled = false
end)

panel.StartButton.MouseButton1Click:Connect(function()
	gui.Enabled = false
	Remotes.EnterArena:FireServer()
end)
