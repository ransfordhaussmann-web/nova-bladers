local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:WaitForChild("Remotes")

local lobbyPlayers = {}

local function buildLobbyPayload(player)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	local playerCount = #Players:GetPlayers()
	local modeLabel = "Modus: Training"
	if playerCount >= 3 then
		modeLabel = "Modus: FFA (" .. playerCount .. " Spieler)"
	elseif playerCount == 2 then
		modeLabel = "Modus: 1v1 PvP"
	end

	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = modeLabel,
		leaderboard = LeaderboardManager.getTop(5),
	}
end

local HubManager = {}

function HubManager.isInLobby(player)
	return lobbyPlayers[player] == true
end

function HubManager.teleportToHub(player)
	local character = player.Character
	if not character then return end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	root.CFrame = HubWorldBuilder.getSpawnCFrame()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end

function HubManager.enterLobby(player)
	lobbyPlayers[player] = true
	HubManager.teleportToHub(player)
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubManager.leaveLobby(player)
	lobbyPlayers[player] = nil
end

function HubManager.refreshLobby(player)
	if not HubManager.isInLobby(player) then return end
	Remotes.LobbyReady:FireClient(player, buildLobbyPayload(player))
end

function HubManager.refreshAllLobbies()
	for player in lobbyPlayers do
		HubManager.refreshLobby(player)
	end
end

function HubManager.init()
	HubWorldBuilder.build()

	Players.PlayerAdded:Connect(function(player)
		PlayerDataManager.load(player)

		player.CharacterAdded:Connect(function()
			if HubManager.isInLobby(player) then
				task.defer(function()
					HubManager.teleportToHub(player)
				end)
			end
		end)

		task.spawn(function()
			player:LoadCharacter()
			local data = PlayerDataManager.get(player)
			LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))
			HubManager.enterLobby(player)
		end)

		task.defer(HubManager.refreshAllLobbies)
	end)

	Players.PlayerRemoving:Connect(function(player)
		HubManager.leaveLobby(player)
		PlayerDataManager.save(player)
		task.defer(HubManager.refreshAllLobbies)
	end)

	Remotes.EnterArena.OnServerEvent:Connect(function(player)
		if not HubManager.isInLobby(player) then return end
		HubManager.leaveLobby(player)
	end)
end

return HubManager
