local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers"):WaitForChild("Remotes")

local function bindZonePrompt(prompt: ProximityPrompt)
	if prompt:GetAttribute("Bound") then
		return
	end
	prompt:SetAttribute("Bound", true)

	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then
			return
		end

		local action = prompt:GetAttribute("HubAction")
		if typeof(action) ~= "string" then
			return
		end

		if action == "openBeySelect" then
			local select = player.PlayerGui:FindFirstChild("BeySelect")
			if select then
				select.Enabled = true
			end
			return
		end

		Remotes.HubZoneAction:FireServer(action)
	end)
end

local function bindZonePart(part: BasePart)
	local prompt = part:FindFirstChild("ZonePrompt")
	if prompt and prompt:IsA("ProximityPrompt") then
		bindZonePrompt(prompt)
	end
end

for _, part in CollectionService:GetTagged("NovaHubZone") do
	bindZonePart(part)
end

CollectionService:GetInstanceAddedSignal("NovaHubZone"):Connect(bindZonePart)

local hub = workspace:WaitForChild("NovaHub", 30)
if hub then
	for _, descendant in hub:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "ZonePrompt" then
			bindZonePrompt(descendant)
		end
	end
end
