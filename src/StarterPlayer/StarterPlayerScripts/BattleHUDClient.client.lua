local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hud = player:WaitForChild("PlayerGui"):WaitForChild("BattleHUD")
local statsFrame = hud:WaitForChild("StatsFrame")
local statsLabel = statsFrame:WaitForChild("StatsLabel")
local countdownLabel = hud:WaitForChild("Countdown")

local announceLabel = statsFrame:FindFirstChild("AnnounceLabel")
if not announceLabel then
	announceLabel = Instance.new("TextLabel")
	announceLabel.Name = "AnnounceLabel"
	announceLabel.Size = UDim2.new(1, -12, 0, 28)
	announceLabel.Position = UDim2.new(0, 6, 1, -34)
	announceLabel.BackgroundTransparency = 1
	announceLabel.Font = Enum.Font.GothamBold
	announceLabel.TextSize = 13
	announceLabel.TextColor3 = Color3.fromRGB(255, 200, 80)
	announceLabel.Text = ""
	announceLabel.Parent = statsFrame
end

local controlsHint = hud:FindFirstChild("ControlsHint")
if not controlsHint then
	controlsHint = Instance.new("TextLabel")
	controlsHint.Name = "ControlsHint"
	controlsHint.Size = UDim2.new(0, 300, 0, 48)
	controlsHint.Position = UDim2.new(0, 12, 1, -60)
	controlsHint.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
	controlsHint.BackgroundTransparency = 0.3
	controlsHint.Font = Enum.Font.Gotham
	controlsHint.TextSize = 11
	controlsHint.TextColor3 = Color3.fromRGB(180, 190, 210)
	controlsHint.TextXAlignment = Enum.TextXAlignment.Left
	controlsHint.Text = "WASD Move | Shift Charge | Space Jump/Dive | C RPM | Q Dodge | E Special"
	controlsHint.Parent = hud
	local hintCorner = Instance.new("UICorner")
	hintCorner.CornerRadius = UDim.new(0, 8)
	hintCorner.Parent = controlsHint
end

local function formatStats(stats)
	local lines = {}
	for _, s in stats do
		if s.alive then
			local zone = s.airborne and "AIR" or (s.inBowl and "BOWL" or "OUT")
			local energy = s.energyReady and "ENERGY READY" or ("Energy:" .. tostring(s.special) .. "%")
			local statLine = s.stats and string.format(
				" ATK:%d DEF:%d SPD:%d STA:%d",
				s.stats.Attack or 0, s.stats.Defense or 0, s.stats.Speed or 0, s.stats.Stamina or 0
			) or ""
			table.insert(lines, string.format(
				"[%s] %s\n  HP:%d  RPM:%d  %s%s",
				zone, s.playerName, s.hp, s.spin, energy, statLine
			))
		elseif s.bursted then
			table.insert(lines, string.format("%s  💥 BURST!", s.playerName))
		else
			table.insert(lines, string.format("%s  — OUT —", s.playerName))
		end
	end
	return table.concat(lines, "\n\n")
end

local function flashAnnounce(text, color)
	announceLabel.Text = text
	announceLabel.TextColor3 = color or Color3.fromRGB(255, 200, 80)
	announceLabel.TextTransparency = 0
	task.delay(2.5, function()
		announceLabel.Text = ""
	end)
end

Remotes.BeyStatsUpdate.OnClientEvent:Connect(function(stats)
	statsLabel.Text = formatStats(stats)
end)

Remotes.SpecialAnnounce.OnClientEvent:Connect(function(payload)
	flashAnnounce("⚡ " .. payload.name .. "!", payload.color)
end)

Remotes.BurstEvent.OnClientEvent:Connect(function(payload)
	flashAnnounce("💥 " .. payload.name .. " BURST!", Color3.fromRGB(255, 80, 80))
end)

Remotes.MatchState.OnClientEvent:Connect(function(payload)
	if payload.phase == "Fighting" or payload.phase == "Countdown" then
		hud.Enabled = true
		controlsHint.Visible = payload.phase == "Fighting"
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
	controlsHint.Visible = false
	task.delay(3, function()
		hud.Enabled = false
		countdownLabel.Text = ""
	end)
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		hud.Enabled = false
		controlsHint.Visible = false
	end
end)
