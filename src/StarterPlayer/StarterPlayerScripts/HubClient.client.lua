local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes
local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)

local function waitForHub()
	return workspace:WaitForChild(HubConfig.ROOT_NAME, 30)
end

local function setCharacterHubMode(enabled)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid and enabled then
		humanoid.WalkSpeed = 16
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		setCharacterHubMode(true)
	end
end)

Remotes.EnterArena.OnClientEvent:Connect(function()
	setCharacterHubMode(false)
end)

task.spawn(function()
	local hub = waitForHub()
	if not hub then
		return
	end

	local camera = workspace.CurrentCamera
	if camera then
		camera.CameraType = Enum.CameraType.Custom
	end

	local spawn = hub:WaitForChild("Spawn", 10)
	if spawn and player.Character then
		local hrp = player.Character:FindFirstChild("HumanoidRootPart")
		if hrp then
			hrp.CFrame = spawn.CFrame + Vector3.new(0, 3, 0)
		end
	end
end)
