local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
require(ReplicatedStorage.NovaBladers.RemotesSetup)

HubWorldManager.init()
