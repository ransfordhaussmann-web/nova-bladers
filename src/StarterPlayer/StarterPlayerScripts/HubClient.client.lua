local Players = game:GetService("Players")

local player = Players.LocalPlayer

local function hideBattleUi()
	for _, name in { "BattleHUD", "BeySelect", "MobileControls" } do
		local gui = player.PlayerGui:FindFirstChild(name)
		if gui then
			gui.Enabled = false
		end
	end
end

player:GetAttributeChangedSignal("InHub"):Connect(function()
	if player:GetAttribute("InHub") then
		hideBattleUi()
	end
end)

if player:GetAttribute("InHub") then
	hideBattleUi()
end
