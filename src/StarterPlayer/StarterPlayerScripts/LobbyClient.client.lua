local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local inHub = true
local panelVisible = false
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

local function setPanelVisible(visible)
	panelVisible = visible
	gui.Enabled = visible
end

local function refreshPanel()
	if lastPayload then
		applyPayload(lastPayload)
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideOthers()
	applyPayload(payload)
	inHub = payload.inHub == true

	if payload.showPanel then
		setPanelVisible(true)
	elseif inHub then
		setPanelVisible(false)
	else
		setPanelVisible(true)
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(location)
	inHub = location == "hub"
	if inHub then
		setPanelVisible(panelVisible)
	else
		setPanelVisible(false)
		hideOthers()
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then return end
	if input.KeyCode == Enum.KeyCode.R then
		setPanelVisible(not panelVisible)
		if panelVisible then
			refreshPanel()
		end
	end
end)

panel.StartButton.MouseButton1Click:Connect(function()
	setPanelVisible(false)
	Remotes.EnterArena:FireServer()
end)
