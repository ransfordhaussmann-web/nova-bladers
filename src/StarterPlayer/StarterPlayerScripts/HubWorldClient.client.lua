local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function openBeySelect()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function connectZonePrompts()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones")
	for _, pad in zones:GetChildren() do
		if not pad:IsA("BasePart") then continue end
		local prompt = pad:FindFirstChild("HubPrompt")
		if not prompt then continue end

		local zoneId = pad:GetAttribute("ZoneId")
		prompt.Triggered:Connect(function()
			if zoneId == "ArenaGate" then
				Remotes.EnterArena:FireServer()
			elseif zoneId == "BeyLab" then
				Remotes.OpenBeySelect:FireServer()
				openBeySelect()
			end
		end)
	end
end

Remotes.OpenBeySelect.OnClientEvent:Connect(openBeySelect)

task.spawn(connectZonePrompts)
