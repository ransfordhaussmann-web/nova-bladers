local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local activeZoneId = nil

local hintGui = Instance.new("ScreenGui")
hintGui.Name = "HubZoneHint"
hintGui.ResetOnSpawn = false
hintGui.Enabled = false
hintGui.Parent = player:WaitForChild("PlayerGui")

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "Hint"
hintLabel.AnchorPoint = Vector2.new(0.5, 1)
hintLabel.Position = UDim2.new(0.5, 0, 0.92, 0)
hintLabel.Size = UDim2.fromOffset(360, 56)
hintLabel.BackgroundColor3 = Color3.fromRGB(20, 24, 32)
hintLabel.BackgroundTransparency = 0.25
hintLabel.BorderSizePixel = 0
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextColor3 = Color3.fromRGB(230, 235, 245)
hintLabel.TextSize = 16
hintLabel.TextWrapped = true
hintLabel.Parent = hintGui

local hintCorner = Instance.new("UICorner")
hintCorner.CornerRadius = UDim.new(0, 8)
hintCorner.Parent = hintLabel

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

local function setZoneHint(zoneName, hint)
	if zoneName then
		hintLabel.Text = string.format("[%s]  %s  (E drücken)", zoneName, hint)
		hintGui.Enabled = true
	else
		hintGui.Enabled = false
	end
end

remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = false
	end
end)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)

remotes.LeaveHubPanel.OnClientEvent:Connect(function()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end)

local hub = workspace:WaitForChild("NovaHub", 30)
if hub then
	local zones = hub:WaitForChild("Zones", 10)
	if zones then
		for _, zoneFolder in zones:GetChildren() do
			local trigger = zoneFolder:FindFirstChild("Trigger")
			if trigger then
				trigger.Touched:Connect(function(hit)
					local character = hit.Parent
					if character ~= player.Character then
						return
					end
					local zoneId = trigger:GetAttribute("ZoneId")
					if zoneId == activeZoneId then
						return
					end
					activeZoneId = zoneId
					local pillar = zoneFolder:FindFirstChild("Pillar")
					local prompt = pillar and pillar:FindFirstChild("ZonePrompt")
					if prompt then
						setZoneHint(prompt.ObjectText, prompt.ActionText)
					end
				end)
				trigger.TouchEnded:Connect(function(hit)
					local character = hit.Parent
					if character ~= player.Character then
						return
					end
					activeZoneId = nil
					setZoneHint(nil)
				end)
			end
		end
	end
end
