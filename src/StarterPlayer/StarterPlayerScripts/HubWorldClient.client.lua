local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hubFolder = workspace:WaitForChild("NovaHub", 30)
local portalSpinConnection

local function hideBattleUi()
	for _, name in { "BattleHUD", "BeySelect", "MobileControls" } do
		local gui = player.PlayerGui:FindFirstChild(name)
		if gui then gui.Enabled = false end
	end
end

local function styleLobbyHud()
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if not gui then return end
	local panel = gui:FindFirstChild("Panel")
	if not panel then return end

	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -16, 0, 16)
	panel.Size = UDim2.new(0, 260, 0, 200)

	local startBtn = panel:FindFirstChild("StartButton")
	if startBtn then
		startBtn.Visible = false
	end
end

local function updateHubBoards(payload)
	if not hubFolder then return end

	local lbBoard = hubFolder:FindFirstChild("LeaderboardBoard", true)
	if lbBoard and payload.leaderboard then
		local gui = lbBoard:FindFirstChild("BoardGui")
		local subtitle = gui and gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Subtitle")
		if subtitle then
			local lines = {}
			for _, entry in payload.leaderboard do
				table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
			end
			subtitle.Text = #lines > 0 and table.concat(lines, "\n") or "Noch keine Einträge"
		end
	end

	local modeBoard = hubFolder:FindFirstChild("ModeBoard", true)
	if modeBoard and payload.modeLabel then
		local gui = modeBoard:FindFirstChild("BoardGui")
		local subtitle = gui and gui:FindFirstChild("Frame") and gui.Frame:FindFirstChild("Subtitle")
		if subtitle then
			subtitle.Text = payload.modeLabel
		end
	end
end

local function startPortalAnimation()
	if portalSpinConnection then return end
	local portalGate = hubFolder and hubFolder:FindFirstChild("PortalGate", true)
	if not portalGate then return end

	local baseCFrame = portalGate.CFrame
	portalSpinConnection = RunService.Heartbeat:Connect(function()
		if not portalGate.Parent then
			portalSpinConnection:Disconnect()
			portalSpinConnection = nil
			return
		end
		local t = os.clock() * 0.6
		portalGate.CFrame = baseCFrame * CFrame.Angles(0, t, 0)
	end)

	local pulse = TweenService:Create(portalGate, TweenInfo.new(1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Transparency = 0.35,
	})
	pulse:Play()
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	hideBattleUi()
	styleLobbyHud()
	updateHubBoards(payload)

	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if gui then
		local panel = gui:FindFirstChild("Panel")
		if panel then
			local stats = panel:FindFirstChild("StatsLabel")
			if stats then
				stats.Text = string.format("Wins: %d\nLosses: %d\nRank: %d", payload.wins, payload.losses, payload.rank)
			end
			local mode = panel:FindFirstChild("ModeLabel")
			if mode then
				mode.Text = payload.modeLabel or "Modus: Training"
			end
			local lb = panel:FindFirstChild("LeaderboardLabel")
			if lb and payload.leaderboard then
				lb.Visible = false
			end
		end
		gui.Enabled = true
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

task.defer(function()
	if hubFolder then
		startPortalAnimation()
	end
end)
