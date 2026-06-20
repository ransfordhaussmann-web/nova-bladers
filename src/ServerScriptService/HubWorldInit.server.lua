local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)
local HubWorldManager = require(script.Parent.HubWorldManager)

RemotesSetup.ensure()
HubWorldManager.init()
