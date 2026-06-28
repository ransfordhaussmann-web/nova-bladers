local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local hubFolder = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
if not hubFolder then
	return
end

local glowParts = {}
for _, descendant in hubFolder:GetDescendants() do
	if descendant:IsA("BasePart") and descendant:GetAttribute("PulseGlow") then
		table.insert(glowParts, {
			part = descendant,
			baseTransparency = descendant.Transparency,
		})
	end
end

if #glowParts == 0 then
	return
end

RunService.RenderStepped:Connect(function()
	local pulse = 0.25 + math.sin(os.clock() * 2.5) * 0.15
	for _, entry in glowParts do
		entry.part.Transparency = entry.baseTransparency + pulse
	end
end)
