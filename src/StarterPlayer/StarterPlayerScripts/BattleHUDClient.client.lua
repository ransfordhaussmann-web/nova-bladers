local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hud = player:WaitForChild("PlayerGui"):WaitForChild("BattleHUD")
local statsLabel = hud:WaitForChild("StatsFrame"):WaitForChild("StatsLabel")
local countdownLabel = hud:WaitForChild("Countdown")

local function formatStats(stats)
	local lines = {}
	for _, s in stats do
		if s.alive then
			table.insert(lines, string.format(
				"%s  HP:%d  Spin:%d  SP:%d",
				s.playerName, s.hp, s.spin, s.special
			))
		else
			table.insert(lines, string.format("%s  — OUT —", s.playerName))
		end
	end
	return table.concat(lines, "\n")
end

Remotes.BeyStatsUpdate.OnClientEvent:Connect(function(stats)
	statsLabel.Text = formatStats(stats)
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase == "Fighting" or payload.phase == "Countdown" then
		hud.Enabled = true
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
	end

	if payload.phase == "Countdown" and payload.countdown then
		countdownLabel.Text = tostring(payload.countdown)
	elseif payload.phase == "Fighting" then
		countdownLabel.Text = ""
	end
end)

Remotes.MatchResult.OnClientEvent:Connect(function(result)
	countdownLabel.Text = result.won and "SIEG!" or "NIEDERLAGE"
	task.delay(3, function()
		hud.Enabled = false
		countdownLabel.Text = ""
	end)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hud.Enabled = false
	end
end)
