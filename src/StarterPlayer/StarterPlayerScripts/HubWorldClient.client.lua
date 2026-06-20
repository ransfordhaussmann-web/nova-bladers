local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZone = nil
local hintGui

local function ensureHintGui()
	if hintGui then return hintGui end

	local screen = Instance.new("ScreenGui")
	screen.Name = "HubZoneHint"
	screen.ResetOnSpawn = false
	screen.DisplayOrder = 5
	screen.Parent = player:WaitForChild("PlayerGui")

	local frame = Instance.new("Frame")
	frame.Name = "Panel"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.fromOffset(360, 72)
	frame.BackgroundColor3 = Color3.fromRGB(20, 22, 32)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = screen

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -16, 0, 28)
	title.Position = UDim2.fromOffset(8, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 220, 120)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 20
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -16, 0, 28)
	hint.Position = UDim2.fromOffset(8, 34)
	hint.BackgroundTransparency = 1
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.Font = Enum.Font.Gotham
	hint.TextSize = 16
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	hintGui = screen
	return screen
end

local function showZoneHint(payload)
	local gui = ensureHintGui()
	local panel = gui.Panel

	if not payload.zoneId then
		panel.Visible = false
		currentZone = nil
		return
	end

	currentZone = payload.zoneId
	panel.Title.Text = payload.name or ""
	panel.Hint.Text = payload.hint or ""
	panel.Visible = true
end

local function openBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(openBeySelect)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if not currentZone then return end

	if input.KeyCode == Enum.KeyCode.E then
		if currentZone == "BeyLab" then
			Remotes.OpenBeySelect:FireServer()
		elseif currentZone == "ArenaGate" then
			Remotes.EnterArena:FireServer()
		end
	elseif input.KeyCode == Enum.KeyCode.Return or input.KeyCode == Enum.KeyCode.Space then
		if currentZone == "ArenaGate" then
			Remotes.EnterArena:FireServer()
		end
	end
end)
