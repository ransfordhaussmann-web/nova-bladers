local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local hub = Workspace:WaitForChild(HubConfig.MODEL_NAME, 30)
if not hub then
	return
end

local arenaGate = hub:FindFirstChild("Zones") and hub.Zones:FindFirstChild("ArenaGate")
if not arenaGate then
	return
end

local glowParts = {}
for _, descendant in arenaGate:GetDescendants() do
	if descendant:IsA("BasePart") and descendant.Name == "PromptAnchor" then
		table.insert(glowParts, descendant)
	end
end

local start = os.clock()
RunService.RenderStepped:Connect(function()
	local pulse = (math.sin((os.clock() - start) * 2.2) + 1) / 2
	for _, part in glowParts do
		part.Transparency = 0.2 + pulse * 0.35
		local light = part:FindFirstChildOfClass("PointLight")
		if light then
			light.Brightness = 1.4 + pulse * 1.2
		end
	end
end)
