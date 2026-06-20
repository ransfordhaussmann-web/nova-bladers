local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local function getHubZones()
	local hub = Workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then
		return {}
	end
	local zonesFolder = hub:WaitForChild("Zones", 10)
	if not zonesFolder then
		return {}
	end
	return zonesFolder:GetChildren()
end

local function bindZonePrompt(zonePart)
	local prompt = zonePart:FindFirstChild("ZonePrompt")
	local actionValue = zonePart:FindFirstChild("ZoneAction")
	if not prompt or not actionValue then
		return
	end

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then
			return
		end

		local action = actionValue.Value
		if action == "EnterArena" then
			Remotes.EnterArena:FireServer()
		elseif action == "OpenBeySelect" then
			Remotes.OpenBeySelect:FireServer()
		end
	end)
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.HubZoneHint.OnClientEvent:Connect(function(hintText)
	local hud = player.PlayerGui:FindFirstChild("HubHint")
	if not hud then
		hud = Instance.new("ScreenGui")
		hud.Name = "HubHint"
		hud.ResetOnSpawn = false
		hud.Parent = player.PlayerGui

		local label = Instance.new("TextLabel")
		label.Name = "HintLabel"
		label.AnchorPoint = Vector2.new(0.5, 1)
		label.Position = UDim2.new(0.5, 0, 1, -24)
		label.Size = UDim2.new(0.6, 0, 0, 40)
		label.BackgroundTransparency = 0.35
		label.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextSize = 18
		label.Font = Enum.Font.GothamMedium
		label.Parent = hud
	end

	local label = hud:FindFirstChild("HintLabel", true)
	if label then
		label.Text = hintText or ""
		label.Visible = hintText ~= nil and hintText ~= ""
	end
end)

task.spawn(function()
	for _, zonePart in getHubZones() do
		if zonePart:IsA("BasePart") then
			bindZonePrompt(zonePart)
		end
	end

	local hub = Workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	if hub then
		local zonesFolder = hub:FindFirstChild("Zones")
		if zonesFolder then
			zonesFolder.ChildAdded:Connect(function(child)
				if child:IsA("BasePart") then
					bindZonePrompt(child)
				end
			end)
		end
	end
end)
