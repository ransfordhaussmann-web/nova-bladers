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
	setGuiEnabled("MobileControls", false)
end

local function showHubUi()
	hideBattleUi()
	setGuiEnabled("Lobby", false)
	setGuiEnabled("BeySelect", false)
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	setGuiEnabled("Lobby", false)
	setGuiEnabled("BeySelect", true)
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	showHubUi()
end)

player:GetAttributeChangedSignal("inHub"):Connect(function()
	if player:GetAttribute("inHub") then
		showHubUi()
	end
end)

if player:GetAttribute("inHub") then
	showHubUi()
end
