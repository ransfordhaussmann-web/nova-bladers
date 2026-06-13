local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function applyHubLighting(inHub)
	if inHub then
		game.Lighting.ClockTime = 14.5
		game.Lighting.Brightness = 2.4
	else
		game.Lighting.ClockTime = 12
		game.Lighting.Brightness = 2
	end
end

local function onHubStateChanged()
	local inHub = player:GetAttribute(HubConfig.PLAYER_ATTR_IN_HUB) == true
	applyHubLighting(inHub)
end

player:GetAttributeChangedSignal(HubConfig.PLAYER_ATTR_IN_HUB):Connect(onHubStateChanged)
player:GetAttributeChangedSignal(HubConfig.PLAYER_ATTR_IN_ARENA):Connect(onHubStateChanged)

onHubStateChanged()

remotes.ReturnToHub.OnClientEvent:Connect(function()
	-- Reserved for server-initiated hub returns from GameManager.
end)
