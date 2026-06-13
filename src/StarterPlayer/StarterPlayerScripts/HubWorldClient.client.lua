local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HUB_ZONE_TAG = "NovaBladersHubZone"

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function onZoneTriggered(part)
	local action = part:GetAttribute("HubAction")
	if action == "showLobby" then
		Remotes.RequestLobbyData:FireServer()
	elseif action == "enterArena" then
		Remotes.EnterArena:FireServer()
	elseif action == "openBeySelect" then
		Remotes.OpenBeySelect:FireServer()
	end
end

local function bindZone(part)
	if part:GetAttribute("HubZoneBound") then
		return
	end
	part:SetAttribute("HubZoneBound", true)

	local prompt = part:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return
	end

	prompt.Triggered:Connect(function()
		onZoneTriggered(part)
	end)
end

for _, part in CollectionService:GetTagged(HUB_ZONE_TAG) do
	bindZone(part)
end

CollectionService:GetInstanceAddedSignal(HUB_ZONE_TAG):Connect(bindZone)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
