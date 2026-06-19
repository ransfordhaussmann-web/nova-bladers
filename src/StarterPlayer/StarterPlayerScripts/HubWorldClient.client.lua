local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local hub = workspace:WaitForChild("NovaHub", 30)

local function openBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function wireZone(zone)
	local action = zone:GetAttribute("ZoneAction")
	if not action then return end

	local prompt = zone:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then return end
		if action == "EnterArena" then
			Remotes.EnterArena:FireServer()
		elseif action == "OpenBeySelect" then
			Remotes.OpenBeySelect:FireServer()
			openBeySelect()
		elseif action == "ShowStats" then
			Remotes.RefreshHubStats:FireServer()
		end
	end)
end

if hub then
	for _, child in hub:GetChildren() do
		if child:IsA("BasePart") and child:GetAttribute("ZoneAction") then
			wireZone(child)
		end
	end
	hub.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") and child:GetAttribute("ZoneAction") then
			wireZone(child)
		end
	end)
end
