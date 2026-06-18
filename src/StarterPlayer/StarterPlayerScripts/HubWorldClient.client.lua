local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local touchedPads = {}

local function findZonePad(hit)
	local current = hit
	while current and current ~= workspace do
		if current:GetAttribute("ZoneId") then
			return current
		end
		current = current.Parent
	end
	return nil
end

local function onZoneTouched(hit)
	local character = player.Character
	if not character or not hit:IsDescendantOf(character) then
		return
	end

	local pad = findZonePad(hit)
	if not pad or touchedPads[pad] then
		return
	end

	touchedPads[pad] = true
	local remoteName = pad:GetAttribute("RemoteName")
	if remoteName then
		local remote = Remotes:FindFirstChild(remoteName)
		if remote and remote:IsA("RemoteEvent") then
			remote:FireServer()
		end
	end

	task.delay(1.5, function()
		touchedPads[pad] = nil
	end)
end

local function hookZones()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end

	for _, pad in zones:GetChildren() do
		if pad:IsA("BasePart") then
			pad.Touched:Connect(onZoneTouched)
		end
	end
end

local function showHallOfFame(payload)
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if not gui then return end

	local panel = gui:FindFirstChild("Panel")
	if not panel then return end

	if panel:FindFirstChild("StatsLabel") then
		panel.StatsLabel.Text = string.format(
			"Wins: %d\nLosses: %d\nRank: %d",
			payload.wins, payload.losses, payload.rank
		)
	end
	if panel:FindFirstChild("ModeLabel") then
		panel.ModeLabel.Text = payload.modeLabel or "Modus: Training"
	end
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
	task.delay(6, function()
		if player:GetAttribute("inHub") then
			gui.Enabled = false
		end
	end)
end

Remotes.ShowHallOfFame.OnClientEvent:Connect(showHallOfFame)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

task.spawn(hookZones)
