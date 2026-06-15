--[[
	Server-Logik für die 3D-Hub-Welt: Welt bauen, Spieler spawnen,
	Zonen-Aktionen und Lobby-Daten bereitstellen.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local PlayerDataManager = require(script.Parent.PlayerDataManager)
local LeaderboardManager = require(script.Parent.LeaderboardManager)

local Remotes = NovaBladers:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = NovaBladers
end

local function ensureRemote(name: string, className: string)
	local remote = Remotes:FindFirstChild(name)
	if not remote then
		remote = Instance.new(className)
		remote.Name = name
		remote.Parent = Remotes
	end
	return remote
end

local LobbyReady = ensureRemote("LobbyReady", "RemoteEvent")
local EnterArena = ensureRemote("EnterArena", "RemoteEvent")
local HubState = ensureRemote("HubState", "RemoteEvent")
local OpenBeySelect = ensureRemote("OpenBeySelect", "RemoteEvent")
local ReturnToHub = ensureRemote("ReturnToHub", "RemoteEvent")

local hubFolder: Folder
local playersInHub: { [Player]: boolean } = {}

local function getModeLabel(): string
	local count = #Players:GetPlayers()
	if count >= 3 then
		return "Modus: FFA"
	elseif count >= 2 then
		return "Modus: 1v1 PvP"
	end
	return "Modus: Training"
end

local function buildLobbyPayload(player: Player, showUi: boolean)
	local data = PlayerDataManager.get(player)
	local rankPoints = PlayerDataManager.getRankPoints(data)
	return {
		wins = data.Wins,
		losses = data.Losses,
		rank = rankPoints,
		modeLabel = getModeLabel(),
		leaderboard = LeaderboardManager.getTop(5),
		showUi = showUi,
		inHub = true,
	}
end

local function sendLobbyReady(player: Player, showUi: boolean)
	LobbyReady:FireClient(player, buildLobbyPayload(player, showUi))
end

local function setPlayerInHub(player: Player, inHub: boolean)
	playersInHub[player] = inHub or nil
	HubState:FireClient(player, { inHub = inHub })
end

local function teleportCharacterToHub(character: Model)
	local hrp = character:FindFirstChild("HumanoidRootPart")
	if not hrp then
		return
	end
	hrp.CFrame = HubConfig.getSpawnCFrame()
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end

local function placePlayerInHub(player: Player)
	setPlayerInHub(player, true)
	local character = player.Character
	if character then
		teleportCharacterToHub(character)
	end
	sendLobbyReady(player, false)
end

local function handleZoneAction(player: Player, action: string)
	if not playersInHub[player] then
		return
	end

	if action == "EnterArena" then
		setPlayerInHub(player, false)
		EnterArena:FireClient(player, { mode = "match" })
	elseif action == "EnterTraining" then
		setPlayerInHub(player, false)
		EnterArena:FireClient(player, { mode = "training" })
	elseif action == "OpenLobbyUI" then
		sendLobbyReady(player, true)
	elseif action == "OpenBeySelect" then
		OpenBeySelect:FireClient(player)
	end
end

local function bindZonePrompts()
	for _, descendant in hubFolder:GetDescendants() do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "HubPrompt" then
			descendant.Triggered:Connect(function(player)
				local action = descendant:GetAttribute("HubAction")
				if typeof(action) == "string" then
					handleZoneAction(player, action)
				end
			end)
		end
	end
end

hubFolder = HubWorldBuilder.build()
bindZonePrompts()

Players.PlayerAdded:Connect(function(player)
	PlayerDataManager.load(player)
	local data = PlayerDataManager.get(player)
	LeaderboardManager.submit(player, PlayerDataManager.getRankPoints(data))

	player.CharacterAdded:Connect(function(character)
		if playersInHub[player] ~= false then
			task.defer(function()
				teleportCharacterToHub(character)
			end)
		end
	end)

	placePlayerInHub(player)
end)

Players.PlayerRemoving:Connect(function(player)
	playersInHub[player] = nil
	PlayerDataManager.save(player)
end)

EnterArena.OnServerEvent:Connect(function(player)
	-- Client bestätigt Arena-Start; Hub-Status bleibt aus bis ReturnToHub.
	setPlayerInHub(player, false)
end)

ReturnToHub.OnServerEvent:Connect(function(player)
	placePlayerInHub(player)
end)

for _, player in Players:GetPlayers() do
	if not PlayerDataManager.get(player) then
		PlayerDataManager.load(player)
	end
	placePlayerInHub(player)
end
