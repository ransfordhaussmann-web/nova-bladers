local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function setGuiEnabled(name, enabled)
	local gui = player.PlayerGui:FindFirstChild(name)
	if gui then
		gui.Enabled = enabled
	end
end

local function enterHub()
	setGuiEnabled("Lobby", false)
	setGuiEnabled("BattleHUD", false)
	setGuiEnabled("BeySelect", false)
	setGuiEnabled("MobileControls", false)
end

local function enterArena()
	setGuiEnabled("Lobby", false)
end

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state == "hub" then
		enterHub()
	else
		enterArena()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(enterHub)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	setGuiEnabled("Lobby", false)
	setGuiEnabled("BeySelect", true)
end)

enterHub()
