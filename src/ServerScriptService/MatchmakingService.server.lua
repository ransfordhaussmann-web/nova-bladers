local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingService = require(script.Parent.MatchmakingService)

local Remotes, Bindables = RemotesSetup.ensure()
MatchmakingService.init(Remotes, Bindables)

print("[MatchmakingService] Queue ready — Training / PvP / FFA")
