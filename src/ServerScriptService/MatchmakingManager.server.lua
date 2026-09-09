local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes = RemotesSetup.ensure()

Remotes.QueueJoin.OnServerEvent:Connect(function(player, modeId)
	if typeof(modeId) ~= "string" then
		modeId = MatchmakingService.getRecommendedMode()
	end
	MatchmakingService.joinQueue(player, modeId)
end)

Remotes.QueueLeave.OnServerEvent:Connect(function(player)
	MatchmakingService.leaveQueue(player)
end)

task.defer(function()
	local hub = workspace:WaitForChild("Hub", 15)
	if not hub then
		return
	end

	for _, child in hub:GetChildren() do
		if child.Name:match("^ModePad_") then
			local modeId = child.Name:gsub("^ModePad_", "")
			local prompt = child:FindFirstChildOfClass("ProximityPrompt")
			if prompt then
				prompt.Triggered:Connect(function(player)
					MatchmakingService.joinQueue(player, modeId)
				end)
			end
		end
	end
end)

print("[MatchmakingManager] Queue system ready")
