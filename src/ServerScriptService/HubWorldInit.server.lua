local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
require(NovaBladers.RemotesSetup).ensure()

local HubWorldManager = require(script.Parent.HubWorldManager)
HubWorldManager.init()
