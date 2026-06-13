local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local inHub = true
local lastLobbyPayload = nil

local function getLobbyGui()
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if not gui then return nil end
	return gui, gui:FindFirstChild("Panel")
end

local function setPanelVisible(visible)
	local gui, panel = getLobbyGui()
	if gui then
		gui.Enabled = visible
	end
end

local function applyLobbyPayload(payload)
	lastLobbyPayload = payload
	inHub = payload.inHub ~= false

	local gui, panel = getLobbyGui()
	if not gui or not panel then return end

	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
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

	if inHub then
		gui.Enabled = false
	end
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function openBeySelect()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
	setPanelVisible(false)
end

local function openStatsPanel()
	if lastLobbyPayload then
		applyLobbyPayload(lastLobbyPayload)
	end
	local gui = getLobbyGui()
	if gui then
		gui.Enabled = true
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideBattleUi()
	applyLobbyPayload(payload)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	inHub = state.inHub == true
	if inHub then
		setPanelVisible(false)
		hideBattleUi()
	else
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then select.Enabled = false end
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(openBeySelect)

local function bindHubPrompt(prompt)
	if prompt:GetAttribute("_HubBound") then return end
	prompt:SetAttribute("_HubBound", true)

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then return end
		local action = prompt:GetAttribute("HubAction")
		if action == "EnterArena" then
			setPanelVisible(false)
			Remotes.EnterArena:FireServer()
		elseif action == "OpenBeySelect" then
			openBeySelect()
		elseif action == "OpenStats" then
			openStatsPanel()
		end
	end)
end

local function scanHub(container)
	for _, desc in container:GetDescendants() do
		if desc:IsA("ProximityPrompt") and desc.Name == "HubPrompt" then
			bindHubPrompt(desc)
		end
	end
end

task.spawn(function()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if hub then
		scanHub(hub)
		hub.DescendantAdded:Connect(function(desc)
			if desc:IsA("ProximityPrompt") and desc.Name == "HubPrompt" then
				bindHubPrompt(desc)
			end
		end)
	end
end)

local gui, panel = getLobbyGui()
if gui and panel and panel:FindFirstChild("StartButton") then
	panel.StartButton.MouseButton1Click:Connect(function()
		setPanelVisible(false)
		Remotes.EnterArena:FireServer()
	end)
end
