local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local inHub = true
local hubModel = workspace:WaitForChild("NovaBladers_Hub", 30)

local function findHubLabel(zoneName, labelName)
	if not hubModel then return nil end
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then return nil end
	local zone = zones:FindFirstChild(zoneName)
	if not zone then return nil end
	local board = zone:FindFirstChild("Board")
	if not board then return nil end
	local display = board:FindFirstChild("Display")
	if not display then return nil end
	return display:FindFirstChild(labelName)
end

local function setCharacterHubMovement(enabled)
	local character = player.Character
	if not character then return end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = enabled and 16 or 0
		humanoid.JumpPower = enabled and 50 or 0
	end
end

local function wireProximityPrompts()
	if not hubModel then return end
	local zones = hubModel:FindFirstChild("Zones")
	if not zones then return end

	for _, zone in zones:GetDescendants() do
		if zone:IsA("ProximityPrompt") and zone.Name == "HubPrompt" then
			zone.Triggered:Connect(function(triggerPlayer)
				if triggerPlayer ~= player or not inHub then return end
				local action = zone:GetAttribute("HubAction")
				if action == "enterArena" then
					Remotes.EnterArena:FireServer()
				elseif action == "openBeySelect" then
					local select = player.PlayerGui:FindFirstChild("BeySelect")
					if select then
						select.Enabled = true
					end
				end
			end)
		end
	end
end

local function updateWorldDisplays(payload)
	local statsLabel = findHubLabel("Stats", "StatsLabel")
	if statsLabel then
		statsLabel.Text = string.format(
			"%s\n\nWins: %d\nLosses: %d\nRang: %d",
			payload.modeLabel or "Modus: Training",
			payload.wins or 0,
			payload.losses or 0,
			payload.rank or 0
		)
	end

	local leaderboardLabel = findHubLabel("Leaderboard", "LeaderboardLabel")
	if leaderboardLabel and payload.leaderboard then
		local lines = { "🏆 Top Spieler" }
		for _, entry in payload.leaderboard do
			table.insert(lines, string.format("%d. %s (%d)", entry.rank, entry.name, entry.points))
		end
		if #payload.leaderboard == 0 then
			table.insert(lines, "Noch keine Einträge")
		end
		leaderboardLabel.Text = table.concat(lines, "\n")
	end
end

Remotes.HubState.OnClientEvent:Connect(function(state)
	inHub = state.inHub == true
	setCharacterHubMovement(inHub)
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.inHub ~= false then
		inHub = true
		updateWorldDisplays(payload)
		setCharacterHubMovement(true)
	end
end)

if hubModel then
	wireProximityPrompts()
else
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "NovaBladers_Hub" then
			hubModel = child
			wireProximityPrompts()
		end
	end)
end

setCharacterHubMovement(true)
