local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function connectZonePrompts()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then
		return
	end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then
		return
	end

	for _, zonePart in zones:GetChildren() do
		if zonePart:IsA("BasePart") then
			local prompt = zonePart:FindFirstChild("HubPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.Triggered:Connect(function(triggerPlayer)
					if triggerPlayer ~= player then
						return
					end
					local action = prompt:GetAttribute("HubAction")
					if typeof(action) == "string" then
						remotes.HubZoneAction:FireServer(action)
					end
				end)
			end
		end
	end
end

remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

task.defer(connectZonePrompts)
