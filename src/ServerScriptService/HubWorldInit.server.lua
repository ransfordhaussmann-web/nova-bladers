local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

require(ReplicatedStorage.NovaBladers.RemotesSetup)

local HubWorldManager = require(script.Parent.HubWorldManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local remotes = NovaBladers:WaitForChild("Remotes")

local arenaEntryRequest = ServerScriptService:FindFirstChild("ArenaEntryRequest")
if not arenaEntryRequest then
	arenaEntryRequest = Instance.new("BindableEvent")
	arenaEntryRequest.Name = "ArenaEntryRequest"
	arenaEntryRequest.Parent = ServerScriptService
end

HubWorldManager.init()

Players.PlayerAdded:Connect(function(player)
	HubWorldManager.onPlayerAdded(player)
end)

Players.PlayerRemoving:Connect(function(player)
	HubWorldManager.onPlayerRemoving(player)
end)

for _, player in Players:GetPlayers() do
	task.spawn(HubWorldManager.onPlayerAdded, player)
end

remotes.EnterArena.OnServerEvent:Connect(function(player)
	if HubWorldManager.isInArena(player) then
		return
	end
	HubWorldManager.sendToArena(player)
	arenaEntryRequest:Fire(player)
end)

local openBeySelect = remotes:FindFirstChild("OpenBeySelect")
if openBeySelect then
	openBeySelect.OnServerEvent:Connect(function(player)
		if HubWorldManager.isInArena(player) then
			return
		end
		local selectGui = player:FindFirstChild("PlayerGui")
			and player.PlayerGui:FindFirstChild("BeySelect")
		if selectGui then
			selectGui.Enabled = true
		end
	end)
end
