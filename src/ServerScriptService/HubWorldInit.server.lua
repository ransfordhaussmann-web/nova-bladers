local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldManager = require(script.Parent.HubWorldManager)

local remotes = RemotesSetup.ensure()
HubWorldManager.init(remotes)
