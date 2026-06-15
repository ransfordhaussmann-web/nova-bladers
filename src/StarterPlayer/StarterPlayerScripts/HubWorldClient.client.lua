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

local function setHubMovement(enabled)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = enabled and 16 or 0
	end
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if not payload.hubWorld then return end
	setHubMovement(true)
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	setHubMovement(false)
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	setHubMovement(true)
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = true
	end
end)
