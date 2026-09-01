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

local function updatePadQueueCounts(queueSizes)
	local hub = getHubFolder()
	if not hub or not queueSizes then
		return
	end

	for _, child in hub:GetChildren() do
		if child.Name:match("^ModePad_") then
			local padId = child.Name:gsub("^ModePad_", "")
			local billboard = child:FindFirstChild("Label")
			local queueLabel = billboard and billboard:FindFirstChild("QueueCount")
			if queueLabel then
				local count = queueSizes[padId] or 0
				queueLabel.Text = string.format("Warteschlange: %d", count)
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
	updatePadQueueCounts(payload.queueSizes)
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(snapshot)
	if snapshot.inQueue and snapshot.modeId then
		highlightActiveMode(snapshot.modeId)
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" or state.phase == "queued" then
		enableWalking()
		if state.modeId then
			highlightActiveMode(state.modeId)
		end
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	enableWalking()
end)
