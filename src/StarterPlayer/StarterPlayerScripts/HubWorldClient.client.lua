local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hub = workspace:WaitForChild("NovaHub", 30)
local inHub = true

local function setLobbyVisible(visible)
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if gui then
		gui.Enabled = visible
	end
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function enterHubState()
	inHub = true
	hideBattleUi()
	setLobbyVisible(false)
end

remotes.ReturnToHub.OnClientEvent:Connect(enterHubState)

player.CharacterAdded:Connect(function()
	task.wait(0.2)
	if inHub then
		enterHubState()
	end
end)

if hub then
	local zones = hub:WaitForChild("Zones")
	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local prompt = zonePart:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function()
					local zoneId = zonePart:GetAttribute("ZoneId")
					if zoneId then
						remotes.HubZoneAction:FireServer(zoneId)
					end
				end)
			end
		end
	end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not hub then return end

	local hallZone = hub.Zones:FindFirstChild("HallOfFame")
	if hallZone and (root.Position - hallZone.Position).Magnitude <= 14 then
		remotes.HubZoneAction:FireServer("HallOfFame")
	end
end)

remotes.EnterArena.OnClientEvent:Connect(function()
	inHub = false
	setLobbyVisible(false)
end)

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

remotes.ShowHallPanel.OnClientEvent:Connect(function()
	setLobbyVisible(true)
end)

enterHubState()
