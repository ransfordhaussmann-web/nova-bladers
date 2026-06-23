local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)

local player = Players.LocalPlayer
local Remotes = NovaBladers:WaitForChild("Remotes")
local EnterArena = Remotes:WaitForChild("EnterArena")
local OpenBeySelect = Remotes:FindFirstChild("OpenBeySelect")
local RequestLobbyData = Remotes:FindFirstChild("RequestLobbyData")

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function openBeySelectUi()
	hideBattleUi()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function handleHubAction(action)
	if action == "enterArena" then
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
		EnterArena:FireServer()
	elseif action == "openBeySelect" then
		openBeySelectUi()
	elseif action == "showStats" then
		if RequestLobbyData then
			RequestLobbyData:FireServer()
		end
	end
end

local function wireZonePrompts()
	local hub = workspace:WaitForChild(HubConfig.ROOT_NAME, 30)
	if not hub then
		return
	end

	local zones = hub:WaitForChild("Zones")
	for _, zone in zones:GetChildren() do
		local marker = zone:FindFirstChild("Marker")
		local prompt = marker and marker:FindFirstChild("ZonePrompt")
		if prompt and not prompt:GetAttribute("ClientWired") then
			prompt:SetAttribute("ClientWired", true)
			prompt.Triggered:Connect(function(triggeringPlayer)
				if triggeringPlayer ~= player then
					return
				end
				local action = prompt:GetAttribute("HubAction")
				if typeof(action) == "string" and action ~= "none" then
					handleHubAction(action)
				end
			end)
		end
	end
end

HubWorldBuilder.build()
wireZonePrompts()

workspace.ChildAdded:Connect(function(child)
	if child.Name == HubConfig.ROOT_NAME then
		task.defer(wireZonePrompts)
	end
end)

if OpenBeySelect then
	OpenBeySelect.OnClientEvent:Connect(openBeySelectUi)
end
