local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function showZoneHint(text)
	local gui = player.PlayerGui:FindFirstChild("HubHint")
	if not gui then
		gui = Instance.new("ScreenGui")
		gui.Name = "HubHint"
		gui.ResetOnSpawn = false
		gui.Parent = player.PlayerGui

		local label = Instance.new("TextLabel")
		label.Name = "HintLabel"
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -24)
		label.Size = UDim2.fromOffset(420, 36)
		label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		label.BackgroundTransparency = 0.25
		label.BorderSizePixel = 0
		label.Font = Enum.Font.GothamMedium
		label.TextSize = 16
		label.TextColor3 = Color3.fromRGB(235, 235, 245)
		label.Parent = gui

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 8)
		corner.Parent = label
	end

	local label = gui.HintLabel
	label.Text = text
	gui.Enabled = true
end

local function hideZoneHint()
	local gui = player.PlayerGui:FindFirstChild("HubHint")
	if gui then
		gui.Enabled = false
	end
end

Remotes.HubReturned.OnClientEvent:Connect(function()
	showZoneHint("Willkommen zurück im Hub — wähle eine Zone.")
	task.delay(4, hideZoneHint)
end)

local hub = workspace:WaitForChild("NovaBladersHub", 30)
if hub then
	local zones = hub:WaitForChild("Zones", 10)
	if zones then
		for _, zone in zones:GetChildren() do
			local prompt = zone:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.PromptShown:Connect(function()
					showZoneHint(prompt.ObjectText .. " — " .. prompt.ActionText)
				end)
				prompt.PromptHidden:Connect(function()
					hideZoneHint()
				end)
			end
		end
	end
end

-- Keep camera above hub floor when spawning
player.CharacterAdded:Connect(function(character)
	task.wait(0.2)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root and hub and hub.PrimaryPart then
		local spawnY = hub.PrimaryPart.Position.Y + 3
		if root.Position.Y < spawnY - 2 then
			root.CFrame = hub.PrimaryPart.CFrame + Vector3.new(0, 3, 0)
		end
	end
end)
