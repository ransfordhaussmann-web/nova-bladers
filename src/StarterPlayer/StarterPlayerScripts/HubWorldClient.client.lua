local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local function getLobbyGui()
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	return gui
end

local function hideLobbyGui()
	local gui = getLobbyGui()
	if gui then
		gui.Enabled = false
	end
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

Remotes.LobbyReady.OnClientEvent:Connect(function()
	hideBattleUi()
	local gui = getLobbyGui()
	if gui then
		gui.Enabled = true
	end
end)

local function hideBeySelect()
	local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
	if beySelect then beySelect.Enabled = false end
end

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	hideLobbyGui()
	hideBeySelect()
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideLobbyGui()
	hideBeySelect()
	local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
	if beySelect then
		beySelect.Enabled = true
	end
end)

local function connectZonePrompts()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER, 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones")
	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChildOfClass("ProximityPrompt")
		local actionVal = zonePart:FindFirstChild("Action")
		if prompt and actionVal then
			prompt.Triggered:Connect(function()
				local action = actionVal.Value
				if action == "enterArena" then
					hideLobbyGui()
					Remotes.EnterArena:FireServer()
				elseif action == "openBeySelect" then
					Remotes.OpenBeySelect:FireServer()
				elseif action == "showHall" then
					Remotes.ShowHallPanel:FireServer()
				end
			end)
		end
	end
end

task.spawn(connectZonePrompts)

hideLobbyGui()
