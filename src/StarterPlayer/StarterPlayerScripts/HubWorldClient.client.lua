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

local function showHubState()
	hideBattleUi()
	setGuiEnabled("Lobby", false)
end

local function onInHubChanged()
	if player:GetAttribute("inHub") then
		showHubState()
	end
end

player:GetAttributeChangedSignal("inHub"):Connect(onInHubChanged)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	setGuiEnabled("Lobby", false)
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	showHubState()
end)

if player:GetAttribute("inHub") then
	showHubState()
end
