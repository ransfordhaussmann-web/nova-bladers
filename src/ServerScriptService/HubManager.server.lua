local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubManager = require(script.Parent.HubManager)

HubManager.init()

for _, marker in CollectionService:GetTagged("HubZone") do
	local prompt = marker:FindFirstChild("ZonePrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		local action = marker:GetAttribute("ZoneAction")
		prompt.Triggered:Connect(function(player)
			HubManager.handleZoneAction(player, action)
		end)
	end
end

local remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")
remotes:WaitForChild("EnterArena").OnServerEvent:Connect(function(player)
	player:SetAttribute("InMatch", true)
end)
