local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local RemotesSetup = require(NovaBladers.RemotesSetup)
local HubWorldManager = require(script.Parent.HubWorldManager)

local remotes = RemotesSetup.ensure()

HubWorldManager.init()

local function bindPlayer(player)
	local ready = false

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not player.Parent then return end
			if not ready then
				ready = true
				HubWorldManager.onPlayerReady(player)
			elseif HubWorldManager.isInHub(player) then
				HubWorldManager.returnToHub(player)
			end
		end)
	end)

	if player.Character then
		task.defer(function()
			if not player.Parent or ready then return end
			ready = true
			HubWorldManager.onPlayerReady(player)
		end)
	end
end

Players.PlayerAdded:Connect(bindPlayer)
for _, player in Players:GetPlayers() do
	bindPlayer(player)
end

remotes.EnterArena.OnServerEvent:Connect(function(player)
	HubWorldManager.enterArena(player)
end)

remotes.HubZoneAction.OnServerEvent:Connect(function(player, zoneId)
	if typeof(zoneId) == "string" then
		HubWorldManager.handleZoneAction(player, zoneId)
	end
end)

task.spawn(function()
	while true do
		HubWorldManager.tickZones()
		task.wait(0.25)
	end
end)
