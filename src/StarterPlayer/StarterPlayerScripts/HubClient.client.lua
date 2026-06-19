local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local connectedZones = {}

local function getLobbyGui()
	return player:WaitForChild("PlayerGui"):WaitForChild("Lobby")
end

local function setLobbyVisible(visible)
	local gui = getLobbyGui()
	gui.Enabled = visible
end

local function openBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function bindZone(part)
	if connectedZones[part] then
		return
	end

	local zoneId = part:GetAttribute("ZoneId")
	if not zoneId then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = zoneId .. "Prompt"
	prompt.ActionText = HubConfig.ZONES[zoneId] and HubConfig.ZONES[zoneId].label or zoneId
	prompt.ObjectText = "Nova Hub"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = part:GetAttribute("Proximity") or 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then
			return
		end

		if zoneId == "ArenaPortal" then
			setLobbyVisible(false)
			Remotes.EnterArena:FireServer()
		elseif zoneId == "BeyVault" then
			Remotes.OpenBeySelect:FireServer()
			openBeySelect()
		elseif zoneId == "StatsTerminal" or zoneId == "LeaderboardMonument" then
			setLobbyVisible(true)
		end
	end)

	connectedZones[part] = prompt
end

for _, part in CollectionService:GetTagged(HubConfig.HUB_ZONE_TAG) do
	bindZone(part)
end

CollectionService:GetInstanceAddedSignal(HubConfig.HUB_ZONE_TAG):Connect(function(part)
	bindZone(part)
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		setLobbyVisible(true)
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	setLobbyVisible(true)
end)
