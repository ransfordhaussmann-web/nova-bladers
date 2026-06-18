local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function hideLobbyUi()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end

local function openBeySelect()
	hideLobbyUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function applyHubState(inHub)
	if inHub then
		hideLobbyUi()
		hideBattleUi()
	else
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then select.Enabled = false end
	end
end

player:GetAttributeChangedSignal("InHub"):Connect(function()
	applyHubState(player:GetAttribute("InHub") == true)
end)

if player:GetAttribute("InHub") == true then
	applyHubState(true)
end

remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		applyHubState(true)
	end
end)

local function connectZonePrompts()
	local hub = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		if not zonePart:IsA("BasePart") then continue end
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if not prompt then continue end

		local action = zonePart:GetAttribute("ZoneAction")
		prompt.Triggered:Connect(function()
			if player:GetAttribute("InHub") ~= true then return end

			if action == "EnterArena" then
				remotes.EnterArena:FireServer()
			elseif action == "OpenBeySelect" then
				openBeySelect()
			elseif action == "ShowHallOfFame" then
				remotes.ShowHallOfFame:FireServer()
			end
		end)
	end
end

task.defer(connectZonePrompts)

return {}
