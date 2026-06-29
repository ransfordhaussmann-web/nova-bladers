local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProximityPromptService = game:GetService("ProximityPromptService")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubWorldConfig = require(NovaBladers.HubWorldConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local hubRoot = workspace:WaitForChild(HubWorldConfig.ROOT_NAME, 30)
if not hubRoot then
	return
end

local function hideBattleUi()
	local hud = player.PlayerGui:FindFirstChild("BattleHUD")
	if hud then hud.Enabled = false end
	local mobile = player.PlayerGui:FindFirstChild("MobileControls")
	if mobile then mobile.Enabled = false end
end

local function addZonePrompt(trigger)
	if trigger:FindFirstChild("HubPrompt") then return end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "HubPrompt"
	prompt.ActionText = trigger:GetAttribute("Hint") or "Interagieren"
	prompt.ObjectText = trigger:GetAttribute("Label") or "Zone"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = trigger
end

for _, descendant in hubRoot:GetDescendants() do
	if descendant.Name == "ZoneTrigger" and descendant:IsA("BasePart") then
		addZonePrompt(descendant)
	end
end

hubRoot.DescendantAdded:Connect(function(descendant)
	if descendant.Name == "ZoneTrigger" and descendant:IsA("BasePart") then
		addZonePrompt(descendant)
	end
end)

ProximityPromptService.PromptTriggered:Connect(function(prompt, triggerPlayer)
	if triggerPlayer ~= player then return end
	if not prompt:IsDescendantOf(hubRoot) then return end

	local trigger = prompt.Parent
	if not trigger or not trigger:IsA("BasePart") then return end

	local remoteName = trigger:GetAttribute("Remote")
	if remoteName == "EnterArena" then
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then lobby.Enabled = false end
		Remotes.EnterArena:FireServer()
	elseif remoteName == "OpenBeySelect" then
		local select = player.PlayerGui:WaitForChild("BeySelect", 5)
		if select then
			select.Enabled = true
		end
	elseif remoteName == "ShowLobbyStats" then
		local lobby = player.PlayerGui:FindFirstChild("Lobby")
		if lobby then
			lobby.Enabled = true
		end
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function()
	hideBattleUi()
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 16
		humanoid.JumpPower = 50
	end
end)
