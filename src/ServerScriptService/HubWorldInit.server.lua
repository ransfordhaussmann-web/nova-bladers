local Players = game:GetService("Players")

local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldManager.init({
	PlayerDataManager = PlayerDataManager,
	LeaderboardManager = LeaderboardManager,
})

local function onPlayerAdded(player)
	PlayerDataManager.load(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			HubWorldManager.onPlayerReady(player)
		end)
	end)
	if player.Character then
		task.defer(function()
			HubWorldManager.onPlayerReady(player)
		end)
	end
end

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end
Players.PlayerAdded:Connect(onPlayerAdded)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerDataManager.persist(player)
	end
end)
