local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local RemotesSetup = require(NovaBladers.RemotesSetup)

local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init()

local remotes = RemotesSetup.ensure()

remotes.EnterArena.OnServerEvent:Connect(function(player)
	HubWorldManager.enterArena(player)
end)

remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
	if typeof(zoneId) ~= "string" then
		return
	end
	HubWorldManager.handleZoneAction(player, zoneId)
end)
