local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then
		hud.Enabled = false
	end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then
		mobile.Enabled = false
	end
end

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
end)

Remotes.BeySelectOpen.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = player.PlayerGui:WaitForChild("BeySelect")
	select.Enabled = true
end)
