local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)

-- Ensure remotes exist before any client connects
require(ReplicatedStorage.NovaBladers.RemotesSetup)

HubWorldManager.init()
