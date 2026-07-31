local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local queuedModeId = nil

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
			local isQueued = padId == queuedModeId
			if isQueued then
				child.Transparency = 0
				child.Color = Color3.fromRGB(255, 255, 255)
			else
				child.Transparency = isActive and 0.1 or 0.35
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
	if payload.queuedModeId then
		queuedModeId = payload.queuedModeId
		highlightActiveMode(payload.activeModeId)
	end
end)

Remotes.QueueUpdate.OnClientEvent:Connect(function(payload)
	if payload.inQueue then
		queuedModeId = payload.modeId
	else
		queuedModeId = nil
	end
end)

Remotes.HubState.OnClientEvent:Connect(function(state)
	if state.phase == "hub" then
		queuedModeId = nil
		enableWalking()
	elseif state.phase == "queued" then
		queuedModeId = state.modeId
		enableWalking()
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	queuedModeId = nil
	enableWalking()
end)
