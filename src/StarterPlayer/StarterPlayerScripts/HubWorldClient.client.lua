local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)

local function updateBoard(payload)
	local content = HubWorldBuilder.getLeaderboardGui()
	if not content then return end
	local entries = content:FindFirstChild("Entries")
	if not entries or not payload.leaderboard then return end
	entries.Text = HubWorldBuilder.formatLeaderboard(payload.leaderboard)
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		updateBoard(payload)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)
