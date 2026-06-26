local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
local HubConfig = require(NovaBladers.HubConfig)
local Remotes = NovaBladers:WaitForChild("Remotes")

local hubModel = workspace:WaitForChild(HubConfig.HUB_FOLDER_NAME, 30)

local function findBoardBody(boardName)
	if not hubModel then
		return nil
	end
	local board = hubModel:FindFirstChild(boardName)
	if not board then
		return nil
	end
	local gui = board:FindFirstChild("BoardGui")
	local root = gui and gui:FindFirstChild("Root")
	return root and root:FindFirstChild("Body")
end

local function setBoardText(boardName, text)
	local body = findBoardBody(boardName)
	if body and text then
		body.Text = text
	end
end

local function wirePrompts()
	if not hubModel then
		return
	end
	for _, descendant in hubModel:GetDescendants() do
		if descendant:IsA("ProximityPrompt") then
			local action = descendant:GetAttribute("HubAction")
			if action == "EnterArena" then
				descendant.Triggered:Connect(function()
					Remotes.EnterArena:FireServer()
				end)
			elseif action == "OpenBeySelect" then
				descendant.Triggered:Connect(function()
					Remotes.OpenBeySelect:FireServer()
					local select = player.PlayerGui:FindFirstChild("BeySelect")
					if select then
						select.Enabled = true
					end
				end)
			end
		end
	end
end

Remotes.HubBoardUpdate.OnClientEvent:Connect(function(payload)
	if payload.statsText then
		setBoardText("StatsBoard", payload.statsText)
	end
	if payload.leaderboardText then
		setBoardText("LeaderboardBoard", payload.leaderboardText)
	end
end)

Remotes.LobbyReady.OnClientEvent:Connect(function(payload)
	if payload.statsText then
		setBoardText("StatsBoard", payload.statsText)
	end
	if payload.leaderboardText then
		setBoardText("LeaderboardBoard", payload.leaderboardText)
	end
end)

wirePrompts()
