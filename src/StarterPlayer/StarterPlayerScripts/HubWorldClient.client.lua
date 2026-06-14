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

Remotes.HubState.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		hideBattleUi()
		setGuiEnabled("BeySelect", false)
	else
		setGuiEnabled("BattleHUD", true)
		setGuiEnabled("MobileControls", true)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	setGuiEnabled("BeySelect", true)
end)

hideBattleUi()
