local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubBuilder = require(NovaBladers.HubBuilder)

local player = Players.LocalPlayer
local Remotes = NovaBladers:WaitForChild("Remotes")
local EnterArena = Remotes:WaitForChild("EnterArena")

local latestPayload = nil

local function findArenaPrompt()
	local hub = HubBuilder.getHubFolder()
	if not hub then
		return nil
	end
	local platform = hub:FindFirstChild("ArenaGatePlatform", true)
	if platform then
		return platform:FindFirstChild("ArenaPrompt")
	end
	return nil
end

local function update3DDisplays(payload)
	local statsLabel = HubBuilder.getStatsLabel()
	if statsLabel then
		statsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d\n\n%s",
			payload.wins,
			payload.losses,
			payload.rank,
			payload.modeLabel or ""
		)
	end

	local leaderboardLabel = HubBuilder.getLeaderboardLabel()
	if leaderboardLabel and payload.leaderboardText then
		leaderboardLabel.Text = payload.leaderboardText
	end
end

local function hideBattleUI()
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

local function bindPrompt(prompt, handler)
	if prompt:GetAttribute("HubClientBound") then
		return
	end
	prompt:SetAttribute("HubClientBound", true)
	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then
			return
		end
		handler()
	end)
end

local function showLegacyLobbyPanel()
	if not latestPayload then
		return
	end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	local panel = lobby:FindFirstChild("Panel")
	if not panel then
		return
	end
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		latestPayload.wins,
		latestPayload.losses,
		latestPayload.rank
	)
	panel.ModeLabel.Text = latestPayload.modeLabel or "Modus: Training"
	local leaderboardLabel = panel:FindFirstChild("LeaderboardLabel")
	if leaderboardLabel and latestPayload.leaderboard then
		local lines = { "Top Spieler:" }
		for _, entry in latestPayload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #latestPayload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		leaderboardLabel.Text = table.concat(lines, "\n")
	end
	lobby.Enabled = true
end

local function findStatsPrompt()
	local hub = HubBuilder.getHubFolder()
	if not hub then
		return nil
	end
	local kiosk = hub:FindFirstChild("StatsKiosk", true)
	if kiosk then
		return kiosk:FindFirstChild("StatsPrompt")
	end
	return nil
end

local function tryBindPrompts()
	local arenaPrompt = findArenaPrompt()
	if arenaPrompt then
		bindPrompt(arenaPrompt, function()
			local lobby = player.PlayerGui:FindFirstChild("Lobby")
			if lobby then
				lobby.Enabled = false
			end
			EnterArena:FireServer()
		end)
	end

	local statsPrompt = findStatsPrompt()
	if statsPrompt then
		bindPrompt(statsPrompt, showLegacyLobbyPanel)
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	latestPayload = payload
	hideBattleUI()

	if payload.use3DHub then
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = false
		end
		update3DDisplays(payload)
		tryBindPrompts()
	else
		update3DDisplays(payload)
	end
end)

task.spawn(function()
	for _ = 1, 30 do
		if HubBuilder.getHubFolder() then
			tryBindPrompts()
			if latestPayload then
				update3DDisplays(latestPayload)
			end
			break
		end
		task.wait(0.5)
	end
end)

workspace.ChildAdded:Connect(function(child)
	if child.Name == "NovaHub" then
		task.defer(function()
			tryBindPrompts()
			if latestPayload then
				update3DDisplays(latestPayload)
			end
		end)
	end
end)
