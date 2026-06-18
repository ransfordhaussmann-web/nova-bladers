local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then select.Enabled = false end
end)

local function waitForHub()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if prompt then
			prompt.PromptShown:Connect(function()
				local action = zonePart:GetAttribute("ZoneAction")
				if action == "EnterArena" then
					prompt.KeyboardKeyCode = Enum.KeyCode.E
				end
			end)
		end
	end
end

task.spawn(waitForHub)
