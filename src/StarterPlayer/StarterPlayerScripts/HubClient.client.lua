local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function getHubFolder()
	return workspace:WaitForChild("Hub", 30)
end

local function highlightActiveMode(activeModeId)
	local hub = getHubFolder()
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		if child.Name:match("^ModePad_") then
			local padId = child.Name:gsub("^ModePad_", "")
			local isActive = padId == activeModeId
			child.Transparency = isActive and 0.1 or 0.35
		end
	end
end

local function highlightQueuedMode(modeId)
	local hub = getHubFolder()
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		if child.Name:match("^ModePad_") then
			local padId = child.Name:gsub("^ModePad_", "")
			if modeId and padId == modeId then
				child.Color = child:GetAttribute("BaseColor") or child.Color
				child.Transparency = 0.05
			end
		end
	end
end

local function enableWalking()
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.activeModeId then
		highlightActiveMode(payload.activeModeId)
	end
end)

Remotes.QueueState.OnClientEvent:Connect(function(payload)
	if payload.queued and payload.mode then
		highlightQueuedMode(payload.mode)
	elseif payload.counts then
		local bestMode = "training"
		local bestCount = 0
		for modeId, count in payload.counts do
			if count > bestCount then
				bestCount = count
				bestMode = modeId
			end
		end
		highlightActiveMode(bestMode)
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		enableWalking()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	enableWalking()
end)
