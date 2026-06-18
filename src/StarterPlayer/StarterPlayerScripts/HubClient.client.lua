local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil
local hintGui = nil

local ZONE_ACTIONS = {
	Arena = function()
		Remotes.EnterArena:FireServer()
	end,
	BeySelect = function()
		Remotes.OpenBeySelect:FireServer()
	end,
	Leaderboard = function()
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = true
		end
	end,
}

local function ensureHintGui()
	if hintGui then
		return hintGui
	end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 1, -24)
	frame.Size = UDim2.fromOffset(360, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Position = UDim2.fromOffset(12, 8)
	title.Size = UDim2.new(1, -24, 0, 24)
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(240, 240, 255)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromOffset(12, 32)
	hint.Size = UDim2.new(1, -24, 0, 32)
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(180, 185, 200)
	hint.TextSize = 14
	hint.TextWrapped = true
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	hintGui = screen
	return screen
end

local function showZoneHint(payload)
	local gui = ensureHintGui()
	local panel = gui.Panel
	panel.Title.Text = payload.label
	panel.Hint.Text = payload.hint .. "\n[E] zum Betreten"
	panel.Visible = true
	gui.Enabled = true
end

local function hideZoneHint()
	if hintGui then
		hintGui.Panel.Visible = false
	end
	activeZone = nil
end

Remotes.HubZoneTouched.OnClientEvent:Connect(function(payload)
	if player:GetAttribute("InArena") then
		return
	end
	activeZone = payload.zoneId
	showZoneHint(payload)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not activeZone then
		return
	end
	if input.KeyCode ~= Enum.KeyCode.E then
		return
	end
	local action = ZONE_ACTIONS[activeZone]
	if action then
		action()
		if activeZone ~= "Leaderboard" then
			hideZoneHint()
		end
	end
end)

player:GetAttributeChangedSignal("InArena"):Connect(function()
	if player:GetAttribute("InArena") then
		hideZoneHint()
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = false
		end
	end
end)
