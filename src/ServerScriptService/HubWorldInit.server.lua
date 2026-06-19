local Players = game:GetService("Players")

local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init()

local function onCharacterAdded(player)
	task.defer(function()
		HubWorldManager.onPlayerReady(player)
	end)
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		onCharacterAdded(player)
	end
end)

for _, player in Players:GetPlayers() do
	player.CharacterAdded:Connect(function()
		onCharacterAdded(player)
	end)
	if player.Character then
		onCharacterAdded(player)
	end
end
