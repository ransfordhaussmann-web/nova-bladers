local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hintGui = nil
local hintLabel = nil
local hintHideToken = 0

local function ensureHintGui()
	if hintGui then
		return
	end

	hintGui = Instance.new("ScreenGui")
	hintGui.Name = "HubZoneHint"
	hintGui.ResetOnSpawn = false
	hintGui.DisplayOrder = 5
	hintGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "HintFrame"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.fromOffset(420, 44)
	frame.BackgroundColor3 = Color3.fromRGB(20, 24, 36)
	frame.BackgroundTransparency = 0.2
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = hintGui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	hintLabel = Instance.new("TextLabel")
	hintLabel.Size = UDim2.fromScale(1, 1)
	hintLabel.BackgroundTransparency = 1
	hintLabel.Font = Enum.Font.GothamMedium
	hintLabel.TextSize = 16
	hintLabel.TextColor3 = Color3.fromRGB(230, 235, 255)
	hintLabel.Parent = frame
end

local function showHint(text, duration)
	ensureHintGui()
	hintHideToken += 1
	local token = hintHideToken

	local frame = hintGui.HintFrame
	hintLabel.Text = text
	frame.Visible = true
	frame.BackgroundTransparency = 0.2

	TweenService:Create(frame, TweenInfo.new(0.2), { BackgroundTransparency = 0.1 }):Play()

	task.delay(duration or 3, function()
		if token ~= hintHideToken then
			return
		end
		local tween = TweenService:Create(frame, TweenInfo.new(0.25), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Connect(function()
			if token == hintHideToken then
				frame.Visible = false
			end
		end)
	end)
end

local function hideBattleUi()
	local hud = playerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local mobile = playerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	showHint(payload.hint or payload.zone or "Nova Hub", 3.5)
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
	showHint("Willkommen zurück im Nova Hub!", 2.5)
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = playerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
		showHint("Wähle deinen Bey im Labor.", 2.5)
	end
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	local lobby = playerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	showHint("Arena betreten — viel Erfolg!", 2)
end)

task.defer(function()
	showHint("Erkunde den Hub: Arena-Tor, Bey-Labor, Ruhmeshalle", 4)
end)
