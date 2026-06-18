local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local function isInHub()
	return player:GetAttribute("inHub") == true
end

local function openBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function showHallOfFame()
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if not gui then
		return
	end
	local panel = gui:FindFirstChild("Panel")
	if panel and panel:FindFirstChild("StartButton") then
		panel.StartButton.Visible = false
	end
	gui.Enabled = true
end

local function connectZonePrompt(prompt)
	local action = prompt:GetAttribute("ZoneAction")
	if not action then
		return
	end

	prompt.Triggered:Connect(function()
		if not isInHub() then
			return
		end

		if action == "EnterArena" then
			Remotes.EnterArena:FireServer()
		elseif action == "OpenBeySelect" then
			openBeySelect()
		elseif action == "ShowStats" then
			showHallOfFame()
		end
	end)
end

local function watchHub(hub)
	local zones = hub:WaitForChild("Zones")
	for _, zone in zones:GetChildren() do
		local platform = zone:FindFirstChild("Platform")
		if platform then
			local prompt = platform:FindFirstChild("ZonePrompt")
			if prompt then
				connectZonePrompt(prompt)
			end
		end
	end
	zones.ChildAdded:Connect(function(zone)
		task.wait()
		local platform = zone:FindFirstChild("Platform")
		if platform then
			local prompt = platform:FindFirstChild("ZonePrompt")
			if prompt then
				connectZonePrompt(prompt)
			end
		end
	end)
end

local hub = workspace:WaitForChild(HubConfig.HUB_NAME, 30)
if hub then
	watchHub(hub)
end

workspace.ChildAdded:Connect(function(child)
	if child.Name == HubConfig.HUB_NAME then
		watchHub(child)
	end
end)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if gui then
		gui.Enabled = false
	end
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = false
	end
end)
