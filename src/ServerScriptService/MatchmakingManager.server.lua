local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local MatchmakingManager = require(script.Parent.MatchmakingManager)

local Remotes, Bindables = RemotesSetup.ensure()
MatchmakingManager.init(Remotes, Bindables)
