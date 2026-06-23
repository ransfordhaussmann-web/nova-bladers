local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZone = nil

local gui = Instance.new("ScreenGui")
gui.Name = "HubWorldUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 5
gui.Parent = player:WaitForChild("PlayerGui")

local hint = Instance.new("TextLabel")
hint.Name = "ZoneHint"
hint.AnchorPoint = Vector2.new(0.5, 1)
hint.Position = UDim2.new(0.5, 0, 1, -24)
hint.Size = UDim2.new(0, 420, 0, 44)
hint.BackgroundColor3 = Color3.fromRGB(18, 20, 28)
hint.BackgroundTransparency = 0.25
hint.TextColor3 = Color3.fromRGB(240, 240, 250)
hint.TextSize = 20
hint.Font = Enum.Font.GothamMedium
hint.Text = ""
hint.Visible = false
hint.Parent = gui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hint

local function setHint(payload)
	activeZone = payload
	if payload then
		hint.Text = string.format("%s — %s", payload.label, payload.hint)
		hint.Visible = true
	else
		hint.Visible = false
	end
end

Remotes.HubZoneHint.OnClientEvent:Connect(setHint)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not activeZone then
		return
	end
	if activeZone.action == "none" then
		return
	end
	if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.ButtonX then
		Remotes.HubZoneAction:FireServer(activeZone.zoneId)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
