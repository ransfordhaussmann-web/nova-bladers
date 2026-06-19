local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubManager = require(script.Parent.HubManager)

HubManager.init()

local remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

remotes:WaitForChild("EnterArena").OnServerEvent:Connect(function(player)
	if player:GetAttribute("InHub") == false then
		return
	end
	HubManager.enterArena(player)
end)

remotes:WaitForChild("ReturnToHub").OnServerEvent:Connect(function(player)
	HubManager.returnToHub(player)
end)

remotes:WaitForChild("OpenBeySelect").OnServerEvent:Connect(function(player)
	player:SetAttribute("SelectingBey", true)
end)

local function onCharacterAdded(player, character)
	task.defer(function()
		if player:GetAttribute("InHub") ~= false then
			player:SetAttribute("InHub", true)
			HubManager.spawnInHub(player)
		end
	end)
end

local function onPlayerAdded(player)
	player:SetAttribute("InHub", true)
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
	HubManager.onPlayerReady(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	require(script.Parent.PlayerDataManager).save(player)
end)
