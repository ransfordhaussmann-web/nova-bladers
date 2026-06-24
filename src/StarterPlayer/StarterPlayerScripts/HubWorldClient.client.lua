local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local function getLobbyGui()
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("Lobby")
	if not gui then return nil end
	return gui, gui:FindFirstChild("Panel")
end

local function hideBattleUi()
	for _, name in { "BattleHUD", "BeySelect", "MobileControls" } do
		local gui = player.PlayerGui:FindFirstChild(name)
		if gui then
			gui.Enabled = false
		end
	end
end

local function showLobbyPanel()
	local gui, panel = getLobbyGui()
	if not gui then return end
	hideBattleUi()
	gui.Enabled = true
	if panel then
		panel.Visible = true
	end
end

local function hideLobbyPanel()
	local gui = getLobbyGui()
	if gui then
		gui.Enabled = false
	end
end

local function connectZone(zone)
	local zoneId = zone:GetAttribute("ZoneId")
	local prompt = zone:FindFirstChildOfClass("ProximityPrompt")
	if not zoneId or not prompt then return end

	prompt.Triggered:Connect(function()
		if zoneId == "Arena" or zoneId == "HallOfFame" then
			showLobbyPanel()
		elseif zoneId == "BeyLab" then
			hideLobbyPanel()
			local beySelect = player.PlayerGui:FindFirstChild("BeySelect")
			if beySelect then
				beySelect.Enabled = true
			end
		end
	end)
end

local function bindHubZones(hub)
	local zones = hub:FindFirstChild("Zones")
	if not zones then return end
	for _, zone in zones:GetChildren() do
		if zone:GetAttribute("HubZone") then
			connectZone(zone)
		end
	end
	zones.ChildAdded:Connect(function(child)
		if child:GetAttribute("HubZone") then
			connectZone(child)
		end
	end)
end

hideBattleUi()
hideLobbyPanel()

Remotes.HubReturned.OnClientEvent:Connect(function()
	hideBattleUi()
end)

local hub = workspace:WaitForChild("NovaBladersHub", 30)
if hub then
	bindHubZones(hub)
end
