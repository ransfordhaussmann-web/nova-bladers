local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function getHubFolder()
	return workspace:WaitForChild("Hub", 30)
end

local function getModePad(hub, modeId)
	for _, child in hub:GetChildren() do
		if child.Name == "ModePad_" .. modeId then
			return child
		end
	end
	return nil
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

local function updatePadQueueLabels(queueCounts)
	local hub = getHubFolder()
	if not hub or not queueCounts then
		return
	end

	for modeId, count in queueCounts do
		local pad = getModePad(hub, modeId)
		if pad then
			local billboard = pad:FindFirstChild("Label")
			local queueLabel = billboard and billboard:FindFirstChild("QueueLabel")
			if queueLabel then
				local required = ({ training = 1, pvp = 2, ffa = 3 })[modeId] or 1
				queueLabel.Text = string.format("Warteschlange: %d/%d", count, required)
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
	if payload.queueStatus and payload.queueStatus.queueCounts then
		updatePadQueueLabels(payload.queueStatus.queueCounts)
	end
end)

Remotes.QueueStatus.OnClientEvent:Connect(function(queueStatus)
	if queueStatus.queued and queueStatus.mode then
		highlightActiveMode(queueStatus.mode)
	end
	if queueStatus.queueCounts then
		updatePadQueueLabels(queueStatus.queueCounts)
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" or state.phase == "queued" then
		enableWalking()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	enableWalking()
end)
