local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local player = Players.LocalPlayer
local hubModel = Workspace:WaitForChild(HubConfig.ROOT_NAME)

local activeHighlight = nil

local function clearHighlight()
	if activeHighlight then
		activeHighlight:Destroy()
		activeHighlight = nil
	end
end

local function highlightPart(part)
	clearHighlight()
	local highlight = Instance.new("Highlight")
	highlight.Name = "HubZoneHighlight"
	highlight.Adornee = part
	highlight.FillTransparency = 0.7
	highlight.OutlineTransparency = 0
	highlight.DepthMode = Enum.HighlightDepthMode.Occluded
	highlight.Parent = part
	activeHighlight = highlight
end

local function ensureHubMovement(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	humanoid.WalkSpeed = HubConfig.HUB_WALK_SPEED
	humanoid.JumpPower = 50
end

local function findNearestZone(rootPart)
	local nearestPart = nil
	local nearestDistance = 16

	for _, descendant in hubModel:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("HubZone") then
			local distance = (descendant.Position - rootPart.Position).Magnitude
			if distance < nearestDistance then
				nearestDistance = distance
				nearestPart = descendant
			end
		end
	end

	return nearestPart
end

local function bindCharacter(character)
	ensureHubMovement(character)

	local rootPart = character:WaitForChild("HumanoidRootPart")
	local heartbeatConn
	heartbeatConn = game:GetService("RunService").Heartbeat:Connect(function()
		if not player:GetAttribute("InHub") then
			clearHighlight()
			return
		end

		if not character.Parent or not rootPart.Parent then
			heartbeatConn:Disconnect()
			clearHighlight()
			return
		end

		local zonePart = findNearestZone(rootPart)
		if zonePart then
			highlightPart(zonePart)
		else
			clearHighlight()
		end
	end)
end

player:GetAttributeChangedSignal("InHub"):Connect(function()
	if player:GetAttribute("InHub") and player.Character then
		ensureHubMovement(player.Character)
	end
end)

player.CharacterAdded:Connect(function(character)
	task.defer(function()
		if player:GetAttribute("InHub") ~= false then
			bindCharacter(character)
		end
	end)
end)

if player.Character and player:GetAttribute("InHub") ~= false then
	bindCharacter(player.Character)
end
