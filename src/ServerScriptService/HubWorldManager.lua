local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local HubConfig = require(NovaBladers.HubConfig)

local HubWorldManager = {}

local hubFolder
local playerInArena = {}

local function getRemotes()
	return NovaBladers:WaitForChild("Remotes")
end

function HubWorldManager.getHubFolder()
	return hubFolder
end

function HubWorldManager.getSpawnCFrame()
	return HubWorldBuilder.getSpawnCFrame()
end

function HubWorldManager.isInArena(player)
	return playerInArena[player] == true
end

function HubWorldManager.teleportCharacter(player, cframe)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		root.CFrame = cframe
	end
end

function HubWorldManager.teleportToHub(player)
	HubWorldManager.teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
	playerInArena[player] = false
end

function HubWorldManager.sendToArena(player)
	local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
	if not arena then
		warn("[HubWorldManager] Arena folder not found:", HubConfig.ARENA_FOLDER_NAME)
		return false
	end

	local spawn = arena:FindFirstChild("Spawn")
		or arena:FindFirstChild("ArenaSpawn", true)
		or arena:FindFirstChildWhichIsA("SpawnLocation", true)

	local targetCFrame = CFrame.new(HubConfig.HUB_ORIGIN + Vector3.new(0, 5, 0))
	if spawn and spawn:IsA("BasePart") then
		targetCFrame = spawn.CFrame + Vector3.new(0, 3, 0)
	end

	HubWorldManager.teleportCharacter(player, targetCFrame)
	playerInArena[player] = true
	return true
end

function HubWorldManager.returnToHub(player)
	HubWorldManager.teleportToHub(player)
	getRemotes().ReturnToHub:FireClient(player)
end

function HubWorldManager.updateLeaderboardBoard(entries)
	local board = HubWorldBuilder.findLeaderboardBoard()
	if not board then
		return
	end
	local surface = board:FindFirstChildWhichIsA("SurfaceGui", true)
	if not surface then
		return
	end
	local list = surface:FindFirstChild("List", true)
	if not list then
		return
	end

	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		list.Text = "Noch keine Einträge"
	else
		list.Text = table.concat(lines, "\n")
	end
end

function HubWorldManager.bindZoneTouches(onZoneHint)
	if not hubFolder then
		return
	end
	local zones = hubFolder:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zoneFolder in zones:GetChildren() do
		local pad = zoneFolder:FindFirstChild("Pad")
		if not pad then
			continue
		end
		local zoneId = pad:GetAttribute("ZoneId")
		local zoneDef = zoneId and HubConfig.ZONES[zoneId]
		if not zoneDef then
			continue
		end

		pad.Touched:Connect(function(hit)
			local character = hit.Parent
			local player = character and Players:GetPlayerFromCharacter(character)
			if not player or HubWorldManager.isInArena(player) then
				return
			end
			onZoneHint(player, zoneDef.hint, zoneDef.label)
		end)
	end
end

function HubWorldManager.init(onZoneAction)
	hubFolder = HubWorldBuilder.build(function(player, zoneDef)
		if onZoneAction then
			onZoneAction(player, zoneDef.action, zoneDef)
		end
	end)

	task.spawn(function()
		while hubFolder and hubFolder.Parent do
			local LeaderboardManager = require(script.Parent.LeaderboardManager)
			HubWorldManager.updateLeaderboardBoard(LeaderboardManager.getTop(5))
			task.wait(30)
		end
	end)

	return hubFolder
end

function HubWorldManager.onPlayerAdded(player, onReady)
	playerInArena[player] = false

	local function spawnInHub()
		task.defer(function()
			if HubWorldManager.isInArena(player) then
				local arena = workspace:FindFirstChild(HubConfig.ARENA_FOLDER_NAME)
				local spawn = arena and (
					arena:FindFirstChild("Spawn")
						or arena:FindFirstChildWhichIsA("SpawnLocation", true)
				)
				if spawn and spawn:IsA("BasePart") then
					HubWorldManager.teleportCharacter(player, spawn.CFrame + Vector3.new(0, 3, 0))
				end
			else
				HubWorldManager.teleportToHub(player)
				if onReady then
					onReady(player)
				end
			end
		end)
	end

	player.CharacterAdded:Connect(spawnInHub)
	if player.Character then
		spawnInHub()
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playerInArena[player] = nil
end

return HubWorldManager
