local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)

local remotes = RemotesSetup.ensure()
local hub = HubWorldBuilder.build()
HubWorldManager.init(remotes, hub)
HubWorldManager.refreshLeaderboardBoard()

local function onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.2)
		if player.Parent then
			HubWorldManager.onPlayerReady(player)
		end
	end)
	if player.Character then
		task.defer(function()
			HubWorldManager.onPlayerReady(player)
		end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	onPlayerAdded(player)
end

task.spawn(function()
	while true do
		task.wait(30)
		HubWorldManager.refreshLeaderboardBoard()
	end
end)
