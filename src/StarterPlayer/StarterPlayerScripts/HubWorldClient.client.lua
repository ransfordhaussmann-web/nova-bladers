local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function showHint(text)
	local gui = player.PlayerGui:FindFirstChild("HubHint")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "HubHint"
		gui.ResetOnSpawn = false
		gui.DisplayOrder = 50
		gui.Parent = player.PlayerGui

		local label = Instance.new("TextLabel")
		label.Name = "Label"
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 0.92, 0)
		label.Size = UDim2.fromOffset(320, 36)
		label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		label.BackgroundTransparency = 0.25
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamMedium
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 16
		label.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
	end

	local label = gui.Label
	label.Text = text
	gui.Enabled = true
	task.delay(2.5, function()
		if gui and gui.Parent and label.Text == text then
			gui.Enabled = false
		end
	end)
end

Remotes:WaitForChild("OpenBeySelect").OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	showHint("Bey-Auswahl geöffnet")
end)

Remotes:WaitForChild("HubZoneTouched").OnClientEvent:Connect(function(zoneKey)
	if zoneKey == "Arena" then
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = false
		end
		showHint("Arena betreten!")
	elseif zoneKey == "Leaderboard" then
		showHint("Rangliste aktualisiert")
	end
end)
