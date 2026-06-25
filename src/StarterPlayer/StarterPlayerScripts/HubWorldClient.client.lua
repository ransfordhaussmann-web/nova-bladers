local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local currentZoneId = nil

local screenGui = Instance.new("ScreenGui")
screenGui.Name = "HubHints"
screenGui.ResetOnSpawn = false
screenGui.DisplayOrder = 5
screenGui.Parent = player:WaitForChild("PlayerGui")

local hintFrame = Instance.new("Frame")
hintFrame.Name = "HintFrame"
hintFrame.AnchorPoint = Vector2.new(0.5, 1)
hintFrame.Position = UDim2.new(0.5, 0, 1, -24)
hintFrame.Size = UDim2.fromOffset(360, 44)
hintFrame.BackgroundColor3 = Color3.fromRGB(20, 22, 30)
hintFrame.BackgroundTransparency = 0.2
hintFrame.Visible = false
hintFrame.Parent = screenGui

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 10)
corner.Parent = hintFrame

local hintLabel = Instance.new("TextLabel")
hintLabel.Name = "HintLabel"
hintLabel.Size = UDim2.fromScale(1, 1)
hintLabel.BackgroundTransparency = 1
hintLabel.Font = Enum.Font.GothamMedium
hintLabel.TextSize = 16
hintLabel.TextColor3 = Color3.new(1, 1, 1)
hintLabel.Parent = hintFrame

remotes.HubZoneHint.OnClientEvent:Connect(function(payload)
	if payload.zoneId then
		currentZoneId = payload.zoneId
		hintLabel.Text = payload.hint or payload.name
		hintFrame.Visible = true
	else
		currentZoneId = nil
		if payload.hint then
			hintLabel.Text = payload.hint
			hintFrame.Visible = true
			task.delay(3, function()
				if not currentZoneId then
					hintFrame.Visible = false
				end
			end)
		else
			hintFrame.Visible = false
		end
	end
end)

local function tryInteract()
	if not currentZoneId then
		return
	end
	if currentZoneId == "ArenaGate" then
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = false
		end
		remotes.EnterArena:FireServer()
		return
	end
	remotes.HubInteract:FireServer(currentZoneId)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == HubConfig.INTERACT_KEY then
		tryInteract()
	end
end)
