local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local gui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
local panel = gui:WaitForChild("Panel")

local inHub = true

local function hideOthers()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function setHubMovement(enabled)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = enabled and 16 or 0
		humanoid.JumpPower = enabled and 50 or 0
	end
end

local function enterArena()
	if not inHub then return end
	inHub = false
	gui.Enabled = false
	setHubMovement(false)
	Remotes.EnterArena:FireServer()
end

local function connectPortalPrompt()
	local hub = workspace:WaitForChild("NovaBladersHub", 20)
	if not hub then return end
	local portal = hub:WaitForChild("ArenaPortal", 10)
	if not portal then return end
	local pad = portal:WaitForChild("Pad", 5)
	if not pad then return end
	local prompt = pad:WaitForChild("EnterArenaPrompt", 5)
	if prompt and not prompt:GetAttribute("LobbyClientBound") then
		prompt:SetAttribute("LobbyClientBound", true)
		prompt.Triggered:Connect(enterArena)
	end
end

task.spawn(connectPortalPrompt)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	inHub = true
	hideOthers()
	panel.StatsLabel.Text = string.format(
		"Wins: %d\nLosses: %d\nRank: %d",
		payload.wins, payload.losses, payload.rank
	)
	panel.ModeLabel.Text = (payload.modeLabel or "Modus: Training") .. "\nLaufe zur Arena oder tippe Start"
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
	gui.Enabled = true
	setHubMovement(true)
end)

panel.StartButton.MouseButton1Click:Connect(enterArena)

player.CharacterAdded:Connect(function()
	if inHub then
		task.defer(function()
			setHubMovement(true)
		end)
	end
end)
