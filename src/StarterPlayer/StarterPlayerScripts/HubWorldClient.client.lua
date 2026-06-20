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

local function hideBattleUi()
	setGuiEnabled("BattleHUD", false)
	setGuiEnabled("BeySelect", false)
	setGuiEnabled("MobileControls", false)
end

local function hideLobby()
	setGuiEnabled("Lobby", false)
end

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	hideLobby()
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideLobby()
	setGuiEnabled("BeySelect", true)
end)

Remotes.ShowHallPanel.OnClientEvent:Connect(function()
	hideBattleUi()
	setGuiEnabled("Lobby", true)
end)

-- Hub start: walkable world instead of fullscreen lobby panel
task.defer(function()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end)
