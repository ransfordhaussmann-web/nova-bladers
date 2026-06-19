local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local ZONE_ACTIONS = {
	ArenaGate = function()
		Remotes.EnterArena:FireServer()
	end,
	BeyLab = function()
		local select = player.PlayerGui:FindFirstChild("BeySelect")
		if select then
			select.Enabled = true
		end
		Remotes.OpenBeySelect:FireServer()
	end,
	HallOfFame = function()
		Remotes.ShowHallOfFame:FireServer()
	end,
}

local function attachZonePrompt(zonePart)
	local zoneId = zonePart:GetAttribute("ZoneId")
	local action = ZONE_ACTIONS[zoneId]
	if not action then
		return
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ZonePrompt"
	prompt.ActionText = zonePart:GetAttribute("ZoneName") or zoneId
	prompt.ObjectText = zonePart:GetAttribute("ZoneHint") or ""
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = zonePart

	prompt.Triggered:Connect(action)
end

local function setupZones()
	local hub = Workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
	if not hub then
		return
	end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			attachZonePrompt(zonePart)
		end
	end
end

task.spawn(setupZones)
