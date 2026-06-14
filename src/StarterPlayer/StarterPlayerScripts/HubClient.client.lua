local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hub = workspace:WaitForChild("NovaHub", 30)
if not hub then
	return
end

local zones = hub:WaitForChild("Zones")

local function wireZone(zonePart)
	local zoneId = zonePart:GetAttribute("HubZone")
	if not zoneId then
		return
	end

	local prompt = zonePart:FindFirstChild("HubPrompt")
	if not prompt then
		return
	end

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then
			return
		end

		if zoneId == "BeyBooth" then
			local select = player.PlayerGui:FindFirstChild("BeySelect")
			if select then
				select.Enabled = true
			end
			return
		end

		if zoneId == "StatsKiosk" or zoneId == "Leaderboard" then
			local lobby = player.PlayerGui:FindFirstChild("Lobby")
			if lobby then
				lobby.Enabled = true
			end
		end

		Remotes.HubZoneAction:FireServer(zoneId)
	end)
end

for _, zonePart in zones:GetChildren() do
	wireZone(zonePart)
end

zones.ChildAdded:Connect(wireZone)
