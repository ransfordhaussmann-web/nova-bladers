local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = NovaBladers:WaitForChild("Remotes")

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function showBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function bindGarageZone(hubFolder)
	local zones = hubFolder:WaitForChild("Zones", 10)
	if not zones then return end
	local marker = zones:WaitForChild("BeyGarage", 10)
	if not marker then return end

	marker.Touched:Connect(function(hit)
		local character = hit.Parent
		if not character then return end
		local touchedPlayer = Players:GetPlayerFromCharacter(character)
		if touchedPlayer ~= player then return end
		showBeySelect()
	end)
end

local function ensureWalkable(character)
	local humanoid = character:WaitForChild("Humanoid", 5)
	if not humanoid then return end
	humanoid.WalkSpeed = 16
	humanoid.JumpPower = 50

	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end
end

local hubFolder = workspace:WaitForChild(HubConfig.HUB_FOLDER, 30)
if hubFolder then
	bindGarageZone(hubFolder)
end

player.CharacterAdded:Connect(function(character)
	task.wait(0.1)
	ensureWalkable(character)
	hideBattleUi()
end)

if player.Character then
	ensureWalkable(player.Character)
	hideBattleUi()
end

Remotes.LobbyReady.OnClientEvent:Connect(function()
	hideBattleUi()
end)
