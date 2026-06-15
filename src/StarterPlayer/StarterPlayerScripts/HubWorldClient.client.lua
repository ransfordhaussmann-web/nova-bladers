local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)

local function getHubFolder()
	return workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)
end

local function pulseZone(zonePart)
	local original = zonePart.Color
	zonePart.Color = Color3.new(
		math.min(original.R + 0.2, 1),
		math.min(original.G + 0.2, 1),
		math.min(original.B + 0.2, 1)
	)
	task.delay(0.25, function()
		if zonePart.Parent then
			zonePart.Color = original
		end
	end)
end

local function bindZonePrompts(hub)
	for _, zoneConfig in HubConfig.ZONES do
		local zone = hub:WaitForChild(zoneConfig.id, 10)
		if not zone then
			continue
		end
		local prompt = zone:WaitForChild("HubPrompt", 5)
		if not prompt then
			continue
		end
		prompt.PromptShown:Connect(function()
			pulseZone(zone)
		end)
	end
end

local function onInHubChanged()
	local inHub = player:GetAttribute("InHub")
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		local panel = lobby:FindFirstChild("Panel")
		if panel then
			panel.Visible = not inHub
		end
	end
end

player:GetAttributeChangedSignal("InHub"):Connect(onInHubChanged)

task.spawn(function()
	local hub = getHubFolder()
	if hub then
		bindZonePrompts(hub)
	end
	onInHubChanged()
end)
