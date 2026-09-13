local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NovaBladers = ReplicatedStorage:WaitForChild("NovaBladers")
require(NovaBladers.RemotesSetup)

local HubWorldManager = require(ServerScriptService.HubWorldManager)
HubWorldManager.init()
