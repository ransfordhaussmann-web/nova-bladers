local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(ReplicatedStorage.NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local Remotes = NovaBladers:WaitForChild("Remotes")

local HubWorldManager = {}

local hubFolder = nil
local inArena = {}

local function getZonesFolder()
	if not hubFolder then
		return nil
	end
	return hubFolder:FindFirstChild("Zones")
end

local function formatLeaderboard(entries)
	local lines = {}
	for _, entry in entries do
		table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
	end
	if #lines == 0 then
		table.insert(lines, "Noch keine Einträge")
	end
	return table.concat(lines, "\n")
end

local function getModeLabel(playerCount)
	if playerCount <= 1 then
		return "Modus: Training"
	elseif playerCount == 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: FFA"
end

function HubWorldManager.buildHub()
	if hubFolder and hubFolder.Parent then
		hubFolder:Destroy()
	end
	hubFolder = HubWorldBuilder.build()
	return hubFolder
end

function HubWorldManager.getHubFolder()
	return hubFolder
end

function HubWorldManager.isInArena(player)
	return inArena[player] == true
end

function HubWorldManager.updateDisplays(payload)
	local zones = getZonesFolder()
	if not zones then
		return
	end

	local statsBoard = zones:FindFirstChild("StatsBoard")
	if statsBoard then
		local body = statsBoard:FindFirstChild("StatsBody", true)
		if body then
			body.Text = string.format(
				"Wins: %d\nLosses: %d\nRank: %d\n\n%s",
				payload.wins,
				payload.losses,
				payload.rank,
				payload.modeLabel or ""
			)
		end
	end

	local lbBoard = zones:FindFirstChild("LeaderboardBoard")
	if lbBoard and payload.leaderboard then
		local body = lbBoard:FindFirstChild("LeaderboardBody", true)
		if body then
			body.Text = formatLeaderboard(payload.leaderboard)
		end
	end
end

function HubWorldManager.buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(playerCount),
		leaderboard = LeaderboardManager.getTop(5),
	}
end

function HubWorldManager.sendLobbyReady(player, options)
	options = options or {}
	local payload = HubWorldManager.buildLobbyPayload(player)
	payload.showPanel = options.showPanel == true
	HubWorldManager.updateDisplays(payload)
	Remotes.LobbyReady:FireClient(player, payload)
end

function HubWorldManager.spawnInHub(player)
	inArena[player] = false
	local character = player.Character or player.CharacterAdded:Wait()
	local hrp = character:WaitForChild("HumanoidRootPart")
	local spawn = hubFolder and hubFolder:FindFirstChild("HubSpawn")
	local target = HubConfig.ORIGIN + HubConfig.SPAWN_OFFSET
	if spawn then
		target = spawn.Position + Vector3.new(0, 3, 0)
	end
	hrp.CFrame = CFrame.new(target)
	HubWorldManager.sendLobbyReady(player)
end

function HubWorldManager.enterArena(player)
	inArena[player] = true
	local character = player.Character
	if not character then
		return
	end
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if hrp then
		hrp.CFrame = CFrame.new(HubConfig.ORIGIN + HubConfig.TELEPORT.arenaOffset)
	end
end

function HubWorldManager.returnToHub(player)
	task.wait(HubConfig.TELEPORT.hubRespawnDelay)
	if not player.Parent then
		return
	end
	HubWorldManager.spawnInHub(player)
end

function HubWorldManager.connectZonePrompts()
	local zones = getZonesFolder()
	if not zones then
		return
	end

	local arenaPortal = zones:FindFirstChild("ArenaPortal")
	if arenaPortal then
		local prompt = arenaPortal:FindFirstChild("ArenaPortalPrompt")
		if prompt then
			prompt.Triggered:Connect(function(triggerPlayer)
				if inArena[triggerPlayer] then
					return
				end
				HubWorldManager.enterArena(triggerPlayer)
			end)
		end
	end

	local beySelect = zones:FindFirstChild("BeySelect")
	if beySelect then
		local prompt = beySelect:FindFirstChild("BeySelectPrompt")
		if prompt then
			prompt.Triggered:Connect(function(triggerPlayer)
				Remotes.OpenBeySelect:FireClient(triggerPlayer)
			end)
		end
	end

	local statsBoard = zones:FindFirstChild("StatsBoard")
	if statsBoard then
		local prompt = statsBoard:FindFirstChild("StatsBoardPrompt")
		if prompt then
			prompt.Triggered:Connect(function(triggerPlayer)
				HubWorldManager.sendLobbyReady(triggerPlayer, { showPanel = true })
			end)
		end
	end

	local leaderboard = zones:FindFirstChild("LeaderboardBoard")
	if leaderboard then
		local prompt = leaderboard:FindFirstChild("LeaderboardPrompt")
		if prompt then
			prompt.Triggered:Connect(function(triggerPlayer)
				HubWorldManager.sendLobbyReady(triggerPlayer, { showPanel = true })
			end)
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function()
		if inArena[player] then
			return
		end
		task.defer(function()
			HubWorldManager.spawnInHub(player)
		end)
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	inArena[player] = nil
	PlayerDataManager.save(player)
end

return HubWorldManager
