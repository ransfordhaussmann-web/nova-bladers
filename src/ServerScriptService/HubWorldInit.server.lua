local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HubWorldManager = require(script.Parent.HubWorldManager)
local RemotesSetup = require(ReplicatedStorage.NovaBladers.RemotesSetup)

RemotesSetup.getFolder()
HubWorldManager.init()
