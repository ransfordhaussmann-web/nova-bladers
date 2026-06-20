local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local currentZoneAction = nil
local inHub = true

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart")
end

local function findZoneAtPosition(position)
	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER)
	if not hub then return nil end

	local zones = hub:FindFirstChild("Zones")
	if not zones then return nil end

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") and zonePart:GetAttribute("Action") then
			local half = zonePart.Size / 2
			local localPos = zonePart.CFrame:PointToObjectSpace(position)
			if math.abs(localPos.X) <= half.X
				and math.abs(localPos.Y) <= half.Y
				and math.abs(localPos.Z) <= half.Z
			then
				return zonePart:GetAttribute("Action"), zonePart:GetAttribute("Prompt")
			end
		end
	end
	return nil
end

local function updateZone()
	if not inHub then
		currentZoneAction = nil
		return
	end

	local root = getCharacterRoot()
	if not root then
		currentZoneAction = nil
		return
	end

	currentZoneAction = select(1, findZoneAtPosition(root.Position))
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function setHubMode(enabled)
	inHub = enabled
	if enabled then
		hideBattleUi()
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then select.Enabled = false end
	else
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
	end
end

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	setHubMode(true)
end)

Remotes.ShowHallPanel.OnClientEvent:Connect(function()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not inHub then return end
	if input.KeyCode ~= Enum.KeyCode.E then return end
	if not currentZoneAction then return end
	Remotes.HubZoneAction:FireServer(currentZoneAction)
end)

task.spawn(function()
	while true do
		updateZone()
		task.wait(0.15)
	end
end)

setHubMode(true)
