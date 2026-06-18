local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local hubFolder = workspace:WaitForChild("NovaHub", 30)
if not hubFolder then
	return
end

local portal = hubFolder:WaitForChild("ArenaPortal", 10)
local glowParts = {}
if portal then
	for _, name in { "LeftPillar", "RightPillar", "Arch" } do
		local part = portal:FindFirstChild(name)
		if part then
			table.insert(glowParts, part)
		end
	end
end

local galleryParts = {}
local gallery = hubFolder:FindFirstChild("BeyGallery")
if gallery then
	for _, child in gallery:GetDescendants() do
		if child:IsA("BasePart") and child.Name:find("Top") then
			table.insert(galleryParts, {
				part = child,
				baseY = child.Position.Y,
			})
		end
	end
end

local pulseTime = 0
RunService.RenderStepped:Connect(function(dt)
	pulseTime += dt
	local pulse = (math.sin(pulseTime * 2.2) + 1) * 0.5

	for _, part in glowParts do
		part.Transparency = 0.1 + pulse * 0.25
	end

	for index, entry in ipairs(galleryParts) do
		local bob = math.sin(pulseTime * 1.6 + index) * 0.15
		local part = entry.part
		part.CFrame = CFrame.new(part.Position.X, entry.baseY + bob, part.Position.Z)
	end
end)

local function setHubCameraHint()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	camera.FieldOfView = 70
end

player:GetAttributeChangedSignal("InHub"):Connect(function()
	if player:GetAttribute("InHub") then
		setHubCameraHint()
	end
end)

if player:GetAttribute("InHub") ~= false then
	setHubCameraHint()
end
