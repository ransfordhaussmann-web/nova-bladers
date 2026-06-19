local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function hideBattleUi()
	for _, name in { "BattleHUD", "BeySelect", "MobileControls" } do
		local gui = player.PlayerGui:FindFirstChild(name)
		if gui then gui.Enabled = false end
	end
end

local function openBeySelect()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

Remotes.OpenBeySelect.OnClientEvent:Connect(openBeySelect)

Remotes.EnterArena.OnClientEvent:Connect(function()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
	hideBattleUi()
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	hideBattleUi()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then lobby.Enabled = false end
end)
