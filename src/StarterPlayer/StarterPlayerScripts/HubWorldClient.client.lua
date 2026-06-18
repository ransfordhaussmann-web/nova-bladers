local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function getLobbyGui()
	local gui = player:WaitForChild("PlayerGui"):FindFirstChild("Lobby")
	return gui
end

local function setBeySelectVisible(visible)
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = visible
	end
end

local function bindZonePrompts()
	local hub = workspace:WaitForChild("NovaHub", 30)
	if not hub then return end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then return end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("ZonePrompt")
		if not prompt then continue end

		prompt.Triggered:Connect(function()
			if player:GetAttribute("inHub") ~= true then return end

			local action = prompt:GetAttribute("ZoneAction")
			if action == "EnterArena" then
				Remotes.EnterArena:FireServer()
			elseif action == "OpenBeySelect" then
				setBeySelectVisible(true)
				Remotes.OpenBeySelect:FireServer()
			elseif action == "ShowStats" then
				local gui = getLobbyGui()
				if gui then
					gui.Enabled = true
				end
			end
		end)
	end
end

task.defer(bindZonePrompts)

Remotes.ReturnToHub.OnClientEvent:Connect(function()
	player:SetAttribute("inHub", true)
	local gui = getLobbyGui()
	if gui then gui.Enabled = false end
	setBeySelectVisible(false)
end)
