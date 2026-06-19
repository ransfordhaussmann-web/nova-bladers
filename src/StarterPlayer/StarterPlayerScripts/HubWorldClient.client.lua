local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local function findZonePrompts()
	local prompts = {}
	local hub = Workspace:WaitForChild("NovaHub", 30)
	if not hub then
		return prompts
	end

	local zones = hub:WaitForChild("Zones", 10)
	if not zones then
		return prompts
	end

	for _, zonePart in zones:GetChildren() do
		local prompt = zonePart:FindFirstChild("HubPrompt")
		if prompt and prompt:IsA("ProximityPrompt") then
			table.insert(prompts, {
				part = zonePart,
				prompt = prompt,
				action = zonePart:GetAttribute("ZoneAction"),
			})
		end
	end

	return prompts
end

local function enableBeySelect()
	local select = player.PlayerGui:FindFirstChild("BeySelect")
	if select then
		select.Enabled = true
	end
end

local function setLobbyVisible(visible)
	local gui = player.PlayerGui:FindFirstChild("Lobby")
	if gui then
		gui.Enabled = visible
	end
end

task.spawn(function()
	local zonePrompts = findZonePrompts()
	for _, entry in zonePrompts do
		entry.prompt.Triggered:Connect(function(triggerPlayer)
			if triggerPlayer ~= player then
				return
			end

			if entry.action == "enterArena" then
				Remotes.EnterArena:FireServer()
			elseif entry.action == "openBeySelect" then
				Remotes.OpenBeySelect:FireServer()
				enableBeySelect()
			elseif entry.action == "showStats" then
				setLobbyVisible(true)
			end
		end)
	end
end)

Remotes.OpenBeySelect.OnClientEvent:Connect(enableBeySelect)

-- Ruhmeshalle: Stats-Panel beim Betreten der Zone anzeigen
task.spawn(function()
	local hub = Workspace:WaitForChild("NovaHub", 30)
	if not hub then
		return
	end
	local zones = hub:WaitForChild("Zones", 10)
	if not zones then
		return
	end
	local hallZone = zones:FindFirstChild("HallOfFame")
	if not hallZone then
		return
	end

	local wasInside = false
	while true do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			local offset = root.Position - hallZone.Position
			local half = hallZone.Size / 2
			local inside = math.abs(offset.X) <= half.X
				and math.abs(offset.Y) <= half.Y + 4
				and math.abs(offset.Z) <= half.Z

			if inside and not wasInside then
				setLobbyVisible(true)
				wasInside = true
			elseif not inside and wasInside then
				setLobbyVisible(false)
				wasInside = false
			end
		end
		task.wait(0.25)
	end
end)
