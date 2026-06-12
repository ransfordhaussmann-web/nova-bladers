local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local HubWorldConfig = require(ReplicatedStorage.NovaBladers.HubWorldConfig)

local HubWorldManager = {}

local inArena = {}
local initialized = false

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager._teleportToHub(player)
end

function HubWorldManager.sendToArena(player)
	HubWorldManager._teleportToArena(player)
end

function HubWorldManager._teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubWorldConfig.HUB.SPAWN)
	inArena[player] = nil
end

function HubWorldManager._teleportToArena(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = CFrame.new(HubWorldConfig.ARENA_SPAWN)
	inArena[player] = true
end

function HubWorldManager.init(remotes)
	if initialized then return end
	initialized = true

	HubWorldBuilder.build()

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			if not inArena[player] then
				task.defer(HubWorldManager._teleportToHub, player)
			end
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		inArena[player] = nil
	end)

	remotes.EnterArena.OnServerEvent:Connect(function(player)
		HubWorldManager._teleportToArena(player)
	end)

	task.spawn(function()
		local hub = workspace:WaitForChild(HubWorldConfig.ROOT_NAME, 10)
		if not hub then return end
		local zones = hub:FindFirstChild("Zones")
		if not zones then return end

		local arenaPad = zones:FindFirstChild("ArenaPortal")
		if arenaPad then
			local prompt = arenaPad:FindFirstChild("ZonePrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					HubWorldManager._teleportToArena(player)
				end)
			end
		end

		local beyPad = zones:FindFirstChild("BeySelect")
		if beyPad and remotes:FindFirstChild("OpenBeySelect") then
			local prompt = beyPad:FindFirstChild("ZonePrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					remotes.OpenBeySelect:FireClient(player)
				end)
			end
		end
	end)
end

return HubWorldManager
