local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)
local HubWorldManager = require(script.Parent.HubWorldManager)

RemotesSetup.ensure()
HubWorldManager.init()
HubWorldManager.bindRemotes()

local function onPlayerAdded(player)
	local data = PlayerDataManager.load(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		task.defer(function()
			if not HubWorldManager.isInArena(player) then
				HubWorldManager.onPlayerReady(player)
			end
		end)
	end)

	if player.Character then
		task.defer(function()
			HubWorldManager.onPlayerReady(player)
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in Players:GetPlayers() do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
end)

game:BindToClose(function()
	for _, player in Players:GetPlayers() do
		PlayerDataManager.persist(player)
	end
end)
