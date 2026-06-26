local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local hubFolder = workspace:WaitForChild("NovaHub", 30)

local function findPortalGlow()
	if not hubFolder then return nil end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then return nil end
	return zones:FindFirstChild("PortalGlow")
end

local glow = findPortalGlow()
if glow then
	local baseCFrame = glow.CFrame
	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not glow.Parent then
			connection:Disconnect()
			return
		end
		local pulse = 0.35 + math.sin(os.clock() * 2) * 0.15
		glow.Transparency = pulse
		glow.CFrame = baseCFrame * CFrame.Angles(0, os.clock() * 0.5, 0)
	end)
end

local zones = hubFolder and hubFolder:FindFirstChild("Zones")
if zones then
	local arenaPortal = zones:FindFirstChild("ArenaPortal")
	local prompt = arenaPortal and arenaPortal:FindFirstChild("ArenaPortalPrompt")
	if prompt then
		prompt.PromptShown:Connect(function()
			local char = player.Character
			local hrp = char and char:FindFirstChild("HumanoidRootPart")
			if hrp and glow then
				local light = glow:FindFirstChildOfClass("PointLight")
				if light then
					light.Brightness = 3.5
				end
			end
		end)
		prompt.PromptHidden:Connect(function()
			local light = glow and glow:FindFirstChildOfClass("PointLight")
			if light then
				light.Brightness = 2
			end
		end)
	end
end
