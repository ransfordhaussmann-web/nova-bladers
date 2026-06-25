local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local hub = workspace:WaitForChild("NovaBladersHub", 30)
if not hub then
	return
end

local arenaGate = hub:WaitForChild("ArenaGate", 10)
if not arenaGate then
	return
end

local prompt = arenaGate:FindFirstChildOfClass("ProximityPrompt")
if not prompt then
	prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Arena betreten"
	prompt.ObjectText = "Arena-Tor"
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = arenaGate
end

prompt.Triggered:Connect(function(triggerPlayer)
	if triggerPlayer ~= player then
		return
	end
	Remotes.EnterArena:FireServer()
end)

local function setLobbyMovement(enabled)
	local character = player.Character
	if not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = enabled and 16 or 0
	end
end

Remotes.LobbyReady.OnClientEvent:Connect(function()
	setLobbyMovement(true)
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	setLobbyMovement(true)
end)

player.CharacterAdded:Connect(function()
	task.defer(function()
		setLobbyMovement(true)
	end)
end)
