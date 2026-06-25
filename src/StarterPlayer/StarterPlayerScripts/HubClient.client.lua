local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

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

local function findArenaPrompt()
	local hub = Workspace:WaitForChild("HubWorld", 30)
	if not hub then
		return nil
	end
	local gate = hub:WaitForChild("ArenaGate", 10)
	if not gate then
		return nil
	end
	local portal = gate:WaitForChild("PortalTrigger", 5)
	if not portal then
		return nil
	end
	return portal:WaitForChild("EnterArenaPrompt", 5)
end

local function bindArenaPrompt(prompt)
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function()
		Remotes.EnterArena:FireServer()
	end)
end

local function updateBoard(zoneKey, text)
	local hub = Workspace:FindFirstChild("HubWorld")
	if not hub then
		return
	end
	local board = hub:FindFirstChild(zoneKey .. "Board")
	if not board then
		return
	end
	local gui = board:FindFirstChild(zoneKey .. "Gui")
	if not gui then
		return
	end
	local frame = gui:FindFirstChild("Background")
	if not frame then
		return
	end
	local label = frame:FindFirstChild("Content")
	if label then
		label.Text = text
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideBattleUi()

	updateBoard("StatsBoard", string.format(
		"📊 Deine Stats\n\nWins: %d\nLosses: %d\nRang: %d\n\n%s",
		payload.wins,
		payload.losses,
		payload.rank,
		payload.modeLabel or ""
	))

	local leaderboardLines = {"🏆 Top Spieler", ""}
	if payload.leaderboard then
		for _, entry in payload.leaderboard do
			table.insert(leaderboardLines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(leaderboardLines, "Noch keine Einträge")
		end
	end
	updateBoard("Leaderboard", table.concat(leaderboardLines, "\n"))
end)

task.spawn(function()
	bindArenaPrompt(findArenaPrompt())
end)
