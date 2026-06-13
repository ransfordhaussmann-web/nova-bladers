local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local inArena = false

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function showLobbyUi()
	hideBattleUi()
	gui.Enabled = true
end

local function hideLobbyUi()
	gui.Enabled = false
end

local function openBeySelect()
	hideLobbyUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function applyLobbyPayload(payload)
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins,
		payload.losses,
		payload.rank
	)
	panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"

	if panel:FindFirstChild("LeaderboardLabel") and payload.leaderboard then
		local lines = { "🏆 Top Spieler:" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		panel.LeaderboardLabel.Text = table.concat(lines, "\n")
	end

	inArena = payload.inArena == true
	if inArena then
		hideLobbyUi()
	else
		showLobbyUi()
	end
end

local function onHubPromptTriggered(prompt)
	local zoneId = prompt:GetAttribute("ZoneId")
	if zoneId == "ArenaGate" then
		hideLobbyUi()
		Remotes.EnterArena:FireServer()
	elseif zoneId == "BeyShop" then
		Remotes.OpenBeySelect:FireServer()
	elseif zoneId == "StatsBoard" then
		Remotes.RefreshHubStats:FireServer()
	end
end

local function bindHubPrompts(hubFolder)
	for _, descendant in hubFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "HubPrompt" then
			descendant.Triggered:Connect(function()
				onHubPromptTriggered(descendant)
			end)
		end
	end

	hubFolder.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") and descendant.Name == "HubPrompt" then
			descendant.Triggered:Connect(function()
				onHubPromptTriggered(descendant)
			end)
		end
	end)
end

Remotes.HubState.OnClientEvent:Connect(applyLobbyPayload)
Remotes.LobbyReady.OnClientEvent:Connect(applyLobbyPayload)
Remotes.OpenBeySelect.OnClientEvent:Connect(openBeySelect)

panel.StartButton.MouseButton1Click:Connect(function()
	hideLobbyUi()
	Remotes.EnterArena:FireServer()
end)

task.spawn(function()
	local hubFolder = Workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if hubFolder then
		bindHubPrompts(hubFolder)
	end
end)

showLobbyUi()
