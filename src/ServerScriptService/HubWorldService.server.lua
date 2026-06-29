local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)

local hubRoot = HubWorldBuilder.build()
local inHub = {}

local function teleportToHub(player)
	local character = player.Character
	if not character then return end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	hrp.CFrame = HubWorldBuilder.getSpawnCFrame()
	inHub[player] = true
end

local function onCharacterAdded(player, character)
	if not inHub[player] then return end
	task.defer(function()
		local hrp = character:WaitForChild("HumanoidRootPart", 5)
		if hrp and inHub[player] then
			hrp.CFrame = HubWorldBuilder.getSpawnCFrame()
		end
	end)
end

local function setPlayerInHub(player, enabled)
	inHub[player] = enabled ~= false
	if enabled ~= false then
		teleportToHub(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	inHub[player] = true
	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, character)
	end)
	if player.Character then
		onCharacterAdded(player, player.Character)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	inHub[player] = nil
end)

local remotes = NovaBladers:FindFirstChild("Remotes")
if remotes then
	local leftArena = remotes:FindFirstChild("LeftArena")
	if leftArena then
		leftArena.OnServerEvent:Connect(function(player)
			setPlayerInHub(player, true)
		end)
	end

	local enterArena = remotes:FindFirstChild("EnterArena")
	if enterArena then
		enterArena.OnServerEvent:Connect(function(player)
			inHub[player] = false
		end)
	end
end

