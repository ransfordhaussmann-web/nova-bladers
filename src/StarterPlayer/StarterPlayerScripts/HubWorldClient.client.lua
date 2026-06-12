local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local HubWorldConfig = require(ReplicatedStorage.NovaBladers.HubWorldConfig)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("NovaBladers").Remotes

local hubFolder = Workspace:WaitForChild(HubWorldConfig.HUB_FOLDER_NAME, 30)
if not hubFolder then
	return
end

local function bindPrompt(partName, onTriggered)
	local part = hubFolder:WaitForChild(partName, 10)
	if not part then
		return
	end
	local prompt = part:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		return
	end
	prompt.Triggered:Connect(function(triggerPlayer)
		if triggerPlayer ~= player then
			return
		end
		onTriggered()
	end)
end

bindPrompt("ArenaGate", function()
	remotes.EnterArena:FireServer()
end)

bindPrompt("BeySelectPodium", function()
	remotes.OpenBeySelect:FireServer()
end)

bindPrompt("StatsBoard", function()
	local refreshRemote = remotes:FindFirstChild("RefreshLobby")
	if refreshRemote then
		refreshRemote:FireServer()
	elseif _G.NovaBladersShowLobbyPanel then
		_G.NovaBladersShowLobbyPanel()
	end
end)
