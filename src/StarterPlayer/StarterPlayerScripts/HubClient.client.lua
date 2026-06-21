local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local HUB_ROOT = "NovaBladersHub"

local function openBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function bindPrompt(prompt)
	if prompt:GetAttribute("HubBound") then return end
	prompt:SetAttribute("HubBound", true)

	prompt.Triggered:Connect(function()
		local action = prompt:GetAttribute("HubAction") or prompt.ActionText
		if action == "EnterArena" then
			local lobby = player.PlayerGui:FindFirstChild("Lobby")
			if lobby then lobby.Enabled = false end
			Remotes.EnterArena:FireServer()
		elseif action == "OpenBeySelect" then
			openBeySelect()
		end
	end)
end

local function bindHubPrompts(hub)
	for _, desc in hub:GetDescendants() do
		if desc:IsA("ProximityPrompt") then
			bindPrompt(desc)
		end
	end
	hub.DescendantAdded:Connect(function(desc)
		if desc:IsA("ProximityPrompt") then
			bindPrompt(desc)
		end
	end)
end

local hub = workspace:WaitForChild(HUB_ROOT, 30)
if hub then
	bindHubPrompts(hub)
end
