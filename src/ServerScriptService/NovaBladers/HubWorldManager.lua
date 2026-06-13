local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubConfig = require(ReplicatedStorage.NovaBladers.HubConfig)
local HubWorldBuilder = require(script.Parent.HubWorldBuilder)
local RemotesSetup = require(script.Parent.RemotesSetup)

local HubWorldManager = {}

local remotes
local playersInArena = {}
local promptConnections = {}

local function setHubState(player, inHub)
	player:SetAttribute("InHub", inHub)
	if remotes then
		remotes.HubState:FireClient(player, { inHub = inHub })
	end
end

local function teleportCharacter(player, targetCFrame)
	local character = player.Character
	if not character then
		return
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	root.CFrame = targetCFrame
end

function HubWorldManager.isInArena(player)
	return playersInArena[player] == true
end

function HubWorldManager.sendToArena(player)
	playersInArena[player] = true
	setHubState(player, false)
	teleportCharacter(player, HubWorldBuilder.getArenaSpawnCFrame())
end

function HubWorldManager.returnToHub(player)
	playersInArena[player] = nil
	setHubState(player, true)
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
end

function HubWorldManager.spawnInHub(player)
	setHubState(player, true)
	teleportCharacter(player, HubWorldBuilder.getSpawnCFrame())
end

function HubWorldManager.bindPrompt(prompt, onTriggered)
	if promptConnections[prompt] then
		return
	end
	promptConnections[prompt] = prompt.Triggered:Connect(onTriggered)
end

function HubWorldManager.init(onKiosk, onArena, onBeySelect)
	remotes = RemotesSetup.ensure()
	HubWorldBuilder.build()

	local hub = workspace:FindFirstChild(HubConfig.HUB_FOLDER_NAME)
	local zones = hub and hub:FindFirstChild("Zones")
	if not zones then
		return
	end

	for _, zoneModel in zones:GetChildren() do
		local anchor = zoneModel:FindFirstChild("PromptAnchor")
		local prompt = anchor and anchor:FindFirstChild("HubPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			local action = prompt:GetAttribute("HubAction")
			if action == "kiosk" then
				HubWorldManager.bindPrompt(prompt, onKiosk)
			elseif action == "arena" then
				HubWorldManager.bindPrompt(prompt, onArena)
			elseif action == "beyselect" then
				HubWorldManager.bindPrompt(prompt, onBeySelect)
			end
		end
	end
end

function HubWorldManager.onPlayerAdded(player)
	player.CharacterAdded:Connect(function()
		if HubWorldManager.isInArena(player) then
			task.defer(function()
				teleportCharacter(player, HubWorldBuilder.getArenaSpawnCFrame())
			end)
		else
			task.defer(function()
				HubWorldManager.spawnInHub(player)
			end)
		end
	end)

	if player.Character then
		HubWorldManager.spawnInHub(player)
	end
end

function HubWorldManager.onPlayerRemoving(player)
	playersInArena[player] = nil
end

return HubWorldManager
