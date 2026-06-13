local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local lobbyGui = player:WaitForChild("PlayerGui"):WaitForChild("Lobby")

local function showLobbyPanel()
	lobbyGui.Enabled = true
end

local function hideLobbyPanel()
	lobbyGui.Enabled = false
end

local function bindPrompt(part)
	local prompt = part:FindFirstChild("HubPrompt")
	if not prompt or prompt:GetAttribute("_bound") then
		return
	end
	prompt:SetAttribute("_bound", true)

	prompt.Triggered:Connect(function()
		local interactType = part:GetAttribute("InteractType")
		if interactType == "Arena" or interactType == "Stats" then
			showLobbyPanel()
		elseif interactType == "BeySelect" then
			Remotes.OpenBeySelect:FireServer()
		end
	end)
end

for _, part in CollectionService:GetTagged("HubInteractable") do
	bindPrompt(part)
end

CollectionService:GetInstanceAddedSignal("HubInteractable"):Connect(bindPrompt)

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end)

Remotes.HubStateChanged.OnClientEvent:Connect(function(payload)
	if payload.inHub then
		hideLobbyPanel()
	else
		showLobbyPanel()
	end
end)

if player:GetAttribute("InHub") ~= false then
	hideLobbyPanel()
end

player:GetAttributeChangedSignal("InHub"):Connect(function()
	if player:GetAttribute("InHub") then
		hideLobbyPanel()
	end
end)
