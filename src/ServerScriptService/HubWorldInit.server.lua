local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local PlayerDataManager = require(script.Parent.PlayerDataManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local RemotesSetup = require(NovaBladers.RemotesSetup)
local BeyCatalog = require(NovaBladers.BeyCatalog)
local BeyConfig = require(NovaBladers.BeyConfig)

local remotes = RemotesSetup.ensure()

local validBeyIds = {}
for _, bey in BeyCatalog do
	validBeyIds[bey.id] = true
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
end)

local openBeySelect = remotes:FindFirstChild("OpenBeySelect")
if openBeySelect then
	openBeySelect.OnServerEvent:Connect(function(player)
		if HubWorldManager.isInArena(player) then
			return
		end
		remotes.BeySelectStart:FireClient(player, {
			catalog = BeyCatalog,
			timeout = BeyConfig.SELECTION_TIMEOUT,
		})
	end)
end

local beySelectPick = remotes:FindFirstChild("BeySelectPick")
if beySelectPick then
	beySelectPick.OnServerEvent:Connect(function(player, beyId)
		if typeof(beyId) ~= "string" or not validBeyIds[beyId] then
			return
		end
		PlayerDataManager.setSelectedBey(player, beyId)
	end)
end
