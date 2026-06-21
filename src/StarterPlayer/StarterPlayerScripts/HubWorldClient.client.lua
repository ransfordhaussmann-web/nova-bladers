local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function getOrCreateHintGui()
	local gui = player.PlayerGui:FindFirstChild("HubZoneHint")
	if gui then return gui end

	gui = Instance.new("ScreenGui")
	gui.Name = "HubZoneHint"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player.PlayerGui

	local frame = Instance.new("Frame")
	frame.Name = "Toast"
	frame.AnchorPoint = Vector2.new(0.5, 1)
	frame.Position = UDim2.new(0.5, 0, 0.92, 0)
	frame.Size = UDim2.fromOffset(360, 72)
	frame.BackgroundColor3 = Color3.fromRGB(25, 28, 38)
	frame.BackgroundTransparency = 0.15
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -20, 0, 28)
	title.Position = UDim2.fromOffset(10, 8)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.TextColor3 = Color3.fromRGB(255, 200, 80)
	title.TextSize = 18
	title.TextXAlignment = Enum.TextXAlignment.Left
	title.Parent = frame

	local hint = Instance.new("TextLabel")
	hint.Name = "Hint"
	hint.Size = UDim2.new(1, -20, 0, 28)
	hint.Position = UDim2.fromOffset(10, 36)
	hint.BackgroundTransparency = 1
	hint.Font = Enum.Font.Gotham
	hint.TextColor3 = Color3.fromRGB(220, 220, 230)
	hint.TextSize = 16
	hint.TextXAlignment = Enum.TextXAlignment.Left
	hint.Parent = frame

	return gui
end

local hideToken = 0

local function showZoneHint(payload)
	local gui = getOrCreateHintGui()
	local toast = gui.Toast
	toast.Title.Text = payload.title or "Zone"
	toast.Hint.Text = payload.hint or ""
	toast.Visible = true
	toast.BackgroundTransparency = 0.15

	hideToken += 1
	local token = hideToken
	task.delay(3, function()
		if token ~= hideToken then return end
		local tween = TweenService:Create(toast, TweenInfo.new(0.35), { BackgroundTransparency = 1 })
		tween:Play()
		tween.Completed:Wait()
		if token == hideToken then
			toast.Visible = false
		end
	end)
end

Remotes.HubZoneHint.OnClientEvent:Connect(showZoneHint)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
