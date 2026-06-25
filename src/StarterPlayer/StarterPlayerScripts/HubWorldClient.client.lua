local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZoneId = nil
local gui = Instance.new("ScreenGui")
gui.Name = "HubWorldUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.Name = "ZoneHint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -80)
hint.Size = UDim2.fromOffset(420, 44)
hint.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
hint.BackgroundTransparency = 0.25
hint.BorderSizePixel = 0
hint.Font = Enum.Font.GothamBold
hint.TextColor3 = Color3.new(1, 1, 1)
hint.TextSize = 18
hint.Text = ""
hint.Visible = false
hint.Parent = gui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hint

local leaderboard = Instance.new("Frame")
leaderboard.Name = "LeaderboardOverlay"
leaderboard.AnchorPoint = Vector2.new(0.5, 0.5)
leaderboard.Position = UDim2.fromScale(0.5, 0.5)
leaderboard.Size = UDim2.fromOffset(360, 280)
leaderboard.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
leaderboard.BackgroundTransparency = 0.1
leaderboard.Visible = false
leaderboard.Parent = gui

local lbCorner = Instance.new("UICorner")
lbCorner.CornerRadius = UDim.new(0, 10)
lbCorner.Parent = leaderboard

local lbTitle = Instance.new("TextLabel")
lbTitle.Size = UDim2.new(1, 0, 0, 40)
lbTitle.BackgroundTransparency = 1
lbTitle.Font = Enum.Font.GothamBold
lbTitle.Text = "🏆 Ruhmeshalle"
lbTitle.TextColor3 = Color3.fromRGB(255, 220, 80)
lbTitle.TextSize = 22
lbTitle.Parent = leaderboard

local lbBody = Instance.new("TextLabel")
lbBody.Position = UDim2.new(0, 16, 0, 44)
lbBody.Size = UDim2.new(1, -32, 1, -52)
lbBody.BackgroundTransparency = 1
lbBody.Font = Enum.Font.Gotham
lbBody.TextColor3 = Color3.new(1, 1, 1)
lbBody.TextSize = 16
lbBody.TextXAlignment = Enum.TextXAlignment.Left
lbBody.TextYAlignment = Enum.TextYAlignment.Top
lbBody.Text = ""
lbBody.Parent = leaderboard

local function hideLeaderboard()
	leaderboard.Visible = false
end

local function showLeaderboard(payload)
	local lines = {
		string.format("Dein Rang: %d Punkte (%dW / %dL)", payload.rank or 0, payload.wins or 0, payload.losses or 0),
		"",
		"Top Spieler:",
	}
	for _, entry in payload.leaderboard or {} do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #(payload.leaderboard or {}) == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	lbBody.Text = table.concat(lines, "\n")
	leaderboard.Visible = true
	task.delay(6, hideLeaderboard)
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload and payload.leaderboard then
		showLeaderboard(payload)
		return
	end

	if payload then
		activeZoneId = payload.id
		hint.Text = payload.prompt or payload.name
		hint.Visible = true
	else
		activeZoneId = nil
		hint.Visible = false
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.E then
		return
	end
	if not activeZoneId then
		return
	end
	Remotes.HubInteract:FireServer(activeZoneId)
end)
