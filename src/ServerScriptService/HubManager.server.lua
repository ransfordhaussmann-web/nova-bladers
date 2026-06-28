local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local HubManager = require(script.Parent.HubManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local function ensureRemotes()
	local nova = ReplicatedStorage:FindFirstChild("NovaBladers")
	if not nova then
		nova = Instance.new("Folder")
		nova.Name = "NovaBladers"
		nova.Parent = ReplicatedStorage
	end

	local remotes = nova:FindFirstChild("Remotes")
	if not remotes then
		remotes = Instance.new("Folder")
		remotes.Name = "Remotes"
		remotes.Parent = nova
	end

	local remoteNames = {
		"LobbyReady",
		"EnterArena",
		"ReturnToHub",
		"HubZoneHighlight",
	}

	for _, name in remoteNames do
		if not remotes:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = remotes
		end
	end

	return remotes
end

ensureRemotes()

local hubModel, zoneTriggers = HubWorldBuilder.build()
HubManager.setZoneTriggers(zoneTriggers)
HubManager.bindPrompts(hubModel)
HubManager.bindRemotes()

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	HubManager.onPlayerAdded(player)

	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
end)

Players.PlayerRemoving:Connect(function(player)
	PlayerDataManager.save(player)
	HubManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	PlayerDataManager.load(player)
	HubManager.onPlayerAdded(player)
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed >= HubConfig.ZONE_CHECK_INTERVAL then
		elapsed = 0
		HubManager.updatePlayerZones()
	end
end)
