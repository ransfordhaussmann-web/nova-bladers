local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")

require(NovaBladers.RemotesSetup)

local HubWorldBuilder = require(NovaBladers.HubWorldBuilder)
local HubWorldManager = require(script.Parent.HubWorldManager)

HubWorldBuilder.build()
HubWorldManager.init()
