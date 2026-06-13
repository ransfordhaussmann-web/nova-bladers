local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true

local function setInHub(value)
	inHub = value
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if gui and gui:FindFirstChild("Panel") then
		if inHub then
			gui.Enabled = false
		end
	end
end

Remotes.HubState.OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" and payload.inHub ~= nil then
		setInHub(payload.inHub)
	end
end)

player:GetAttributeChangedSignal("InHub"):Connect(function()
	setInHub(player:GetAttribute("InHub") ~= false)
end)

setInHub(player:GetAttribute("InHub") ~= false)

local hub = workspace:WaitForChild("NovaHub", 30)
if hub then
	local zones = hub:WaitForChild("Zones", 10)
	if zones then
		for _, zoneModel in zones:GetChildren() do
			local anchor = zoneModel:FindFirstChild("PromptAnchor")
			local prompt = anchor and anchor:FindFirstChild("HubPrompt")
			if prompt and prompt:IsA("ProximityPrompt") then
				prompt.PromptShown:Connect(function()
					if inHub then
						prompt.Enabled = true
					end
				end)
			end
		end
	end
end

Remotes.OpenBeySelect.OnClientEvent:Connect(function()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
	local lobby = player.PlayerGui:FindFirstChild("Lobby")
	if lobby then
		lobby.Enabled = false
	end
end)
